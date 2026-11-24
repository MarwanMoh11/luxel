#!/usr/bin/env python3
"""Offline pixel-art PNG-sequence -> H.264 .mp4 encoder using macOS native AVFoundation.

Zero external dependencies or network downloads: compiles a tiny Swift AVAssetWriter
helper via system `swiftc` (cached in /tmp by content hash) with strict nearest-neighbor
upscaling so 320x180 pixel art stays razor-sharp at 640x360 (or custom scale) @ 30fps.

Usage:
  python3 tools/design_critic/encode_motion_mp4.py <frames_dir> <out_mp4> [--fps 30] [--scale 2] [--glob "frame_*.png"]
  python3 tools/design_critic/encode_motion_mp4.py --all <parent_dir> [--fps 30] [--scale 2]
"""

from __future__ import annotations

import argparse
import glob
import hashlib
import os
import subprocess
import sys
import tempfile
from pathlib import Path

SWIFT_SRC = r"""
import Foundation
import AVFoundation
import CoreGraphics
import CoreVideo
import ImageIO

func fail(_ msg: String) -> Never {
    fputs("encode_motion_mp4 swift error: \(msg)\n", stderr)
    exit(1)
}

let args = CommandLine.arguments
if args.count < 6 {
    fail("usage: png2mp4 <list_file> <out_mp4> <fps> <scale> <bitrate>")
}

let listPath = args[1]
let outPath = args[2]
guard let fps = Int32(args[3]), fps > 0 else { fail("invalid fps") }
guard let scale = Int(args[4]), scale >= 1 else { fail("invalid scale") }
guard let bitrate = Int(args[5]), bitrate >= 200_000 else { fail("invalid bitrate") }

guard let rawList = try? String(contentsOfFile: listPath, encoding: .utf8) else {
    fail("cannot read frame list: \(listPath)")
}
let framePaths = rawList
    .split(whereSeparator: \.isNewline)
    .map { String($0).trimmingCharacters(in: .whitespaces) }
    .filter { !$0.isEmpty }
if framePaths.isEmpty {
    fail("no input PNG frames provided")
}

func loadCGImage(_ path: String) -> CGImage {
    let url = URL(fileURLWithPath: path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        fail("failed to decode PNG: \(path)")
    }
    return img
}

let firstImg = loadCGImage(framePaths[0])
let outW = ((firstImg.width * scale) + 1) & ~1
let outH = ((firstImg.height * scale) + 1) & ~1

let outURL = URL(fileURLWithPath: outPath)
try? FileManager.default.removeItem(at: outURL)

guard let writer = try? AVAssetWriter(outputURL: outURL, fileType: .mp4) else {
    fail("failed to create AVAssetWriter for \(outPath)")
}

let videoSettings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: outW,
    AVVideoHeightKey: outH,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: bitrate,
        AVVideoMaxKeyFrameIntervalKey: Int(fps),
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoAllowFrameReorderingKey: false,
    ],
]

let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
writerInput.expectsMediaDataInRealTime = false

let pbAttrs: [String: Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
    kCVPixelBufferWidthKey as String: outW,
    kCVPixelBufferHeightKey as String: outH,
    kCVPixelBufferCGImageCompatibilityKey as String: true,
    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
]
let adaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: writerInput,
    sourcePixelBufferAttributes: pbAttrs
)

guard writer.canAdd(writerInput) else { fail("cannot add writer input") }
writer.add(writerInput)
guard writer.startWriting() else {
    fail("startWriting failed: \(writer.error?.localizedDescription ?? "unknown")")
}
writer.startSession(atSourceTime: .zero)

let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue

guard let pool = adaptor.pixelBufferPool else { fail("missing pixelBufferPool") }

for (idx, fpath) in framePaths.enumerated() {
    while !writerInput.isReadyForMoreMediaData {
        Thread.sleep(forTimeInterval: 0.002)
    }
    var pbOpt: CVPixelBuffer?
    let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbOpt)
    guard status == kCVReturnSuccess, let pb = pbOpt else {
        fail("CVPixelBufferPoolCreatePixelBuffer failed at frame \(idx)")
    }
    CVPixelBufferLockBaseAddress(pb, [])
    defer { CVPixelBufferUnlockBaseAddress(pb, []) }
    guard let baseAddr = CVPixelBufferGetBaseAddress(pb) else {
        fail("missing pixel buffer base address")
    }
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
    guard let ctx = CGContext(
        data: baseAddr,
        width: outW,
        height: outH,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        fail("failed to create CGContext")
    }
    ctx.interpolationQuality = .none
    ctx.setShouldAntialias(false)
    let img = (idx == 0) ? firstImg : loadCGImage(fpath)
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: outW, height: outH))

    let pts = CMTime(value: CMTimeValue(idx), timescale: fps)
    if !adaptor.append(pb, withPresentationTime: pts) {
        fail("append failed at frame \(idx): \(writer.error?.localizedDescription ?? "unknown")")
    }
}

writerInput.markAsFinished()
let sem = DispatchSemaphore(value: 0)
writer.finishWriting { sem.signal() }
sem.wait()

if writer.status != .completed {
    fail("finishWriting failed: \(writer.error?.localizedDescription ?? "unknown")")
}
print("ENCODED \(framePaths.count) frames -> \(outW)x\(outH) @ \(fps)fps: \(outPath)")
"""


def _ensure_swift_binary() -> Path:
    digest = hashlib.sha256(SWIFT_SRC.encode("utf-8")).hexdigest()[:12]
    bin_path = Path(tempfile.gettempdir()) / f"luxel_png2mp4_{digest}"
    if bin_path.is_file() and os.access(bin_path, os.X_OK):
        return bin_path
    src_path = Path(tempfile.gettempdir()) / f"luxel_png2mp4_{digest}.swift"
    src_path.write_text(SWIFT_SRC, encoding="utf-8")
    cmd = [
        "swiftc",
        "-O",
        str(src_path),
        "-o",
        str(bin_path),
        "-framework",
        "AVFoundation",
        "-framework",
        "CoreGraphics",
        "-framework",
        "CoreVideo",
        "-framework",
        "ImageIO",
        "-framework",
        "CoreMedia",
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"swiftc compile failed:\n{res.stderr}\n{res.stdout}")
    return bin_path


def encode_sequence(
    frames_dir: Path,
    out_mp4: Path,
    fps: int = 30,
    scale: int = 2,
    pattern: str = "frame_*.png",
    bitrate: int = 3_000_000,
    max_frames: int = 0,
) -> Path:
    matches = sorted(glob.glob(str(frames_dir / pattern)))
    if max_frames > 0:
        matches = matches[:max_frames]
    if not matches:
        raise FileNotFoundError(f"No PNG frames matching '{pattern}' in {frames_dir}")
    out_mp4.parent.mkdir(parents=True, exist_ok=True)
    bin_path = _ensure_swift_binary()
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False, encoding="utf-8") as tf:
        tf.write("\n".join(os.path.abspath(p) for p in matches) + "\n")
        list_file = tf.name
    try:
        res = subprocess.run(
            [str(bin_path), list_file, str(out_mp4.resolve()), str(fps), str(scale), str(bitrate)],
            capture_output=True,
            text=True,
        )
        if res.returncode != 0:
            raise RuntimeError(f"encoder failed:\n{res.stderr}\n{res.stdout}")
        print(res.stdout.strip())
    finally:
        try:
            os.unlink(list_file)
        except OSError:
            pass
    return out_mp4


def main() -> int:
    ap = argparse.ArgumentParser(description="Encode pixel-art PNG sequences into H.264 .mp4 via macOS AVFoundation.")
    ap.add_argument("frames_dir", nargs="?", help="Directory containing PNG frames (or parent dir with --all)")
    ap.add_argument("out_mp4", nargs="?", help="Output .mp4 file path (omitted when using --all)")
    ap.add_argument("--all", dest="batch_dir", help="Encode every clip subdirectory inside this folder to <clip>.mp4")
    ap.add_argument("--fps", type=int, default=30, help="Frames per second (default: 30)")
    ap.add_argument("--scale", type=int, default=2, help="Integer nearest-neighbor scale factor (default: 2 -> 640x360)")
    ap.add_argument("--glob", dest="pattern", default="frame_*.png", help="Filename glob inside frames_dir (default: frame_*.png)")
    ap.add_argument("--bitrate", type=int, default=3_000_000, help="H.264 target bitrate in bps (default: 3000000)")
    ap.add_argument("--max-frames", type=int, default=0, help="Optional cap on number of frames encoded")
    args = ap.parse_args()

    if args.batch_dir:
        parent = Path(args.batch_dir)
        if not parent.is_dir():
            print(f"ERROR: directory not found: {parent}", file=sys.stderr)
            return 1
        subdirs = sorted(p for p in parent.iterdir() if p.is_dir())
        encoded = 0
        for sub in subdirs:
            if not list(sub.glob(args.pattern)):
                continue
            out_path = parent / f"{sub.name}.mp4"
            encode_sequence(sub, out_path, args.fps, args.scale, args.pattern, args.bitrate, args.max_frames)
            encoded += 1
        if encoded == 0:
            print(f"ERROR: no clip subdirectories with '{args.pattern}' found in {parent}", file=sys.stderr)
            return 1
        print(f"MOTION MP4 BATCH PASS: encoded={encoded} dir={parent}")
        return 0

    if not args.frames_dir or not args.out_mp4:
        ap.print_help()
        return 2

    encode_sequence(
        Path(args.frames_dir),
        Path(args.out_mp4),
        args.fps,
        args.scale,
        args.pattern,
        args.bitrate,
        args.max_frames,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
