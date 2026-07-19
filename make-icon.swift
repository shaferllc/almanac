#!/usr/bin/env swift
// Generates AppIcon.icns: a deep-navy squircle with an open almanac page
// under a gold compass star — the navigator's book of dates and positions.
// Usage: swift make-icon.swift  (run from the almanac dir)

import AppKit
import Foundation

let here    = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = here.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

func starPath(center: NSPoint, longRadius: CGFloat, shortRadius: CGFloat, rotation: CGFloat = 0) -> NSBezierPath {
    // Four-point compass star: 8 vertices alternating long/short radii.
    let path = NSBezierPath()
    for i in 0..<8 {
        let angle = rotation + .pi / 2 + CGFloat(i) * .pi / 4
        let radius = i % 2 == 0 ? longRadius : shortRadius
        let pt = NSPoint(x: center.x + cos(angle) * radius,
                         y: center.y + sin(angle) * radius)
        if i == 0 { path.move(to: pt) } else { path.line(to: pt) }
    }
    path.close()
    return path
}

func makePNG(size px: Int) -> Data? {
    let pf = CGFloat(px)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32)
    else { return nil }
    rep.size = NSSize(width: pf, height: pf)

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.current = ctx

    // Squircle background: midnight navy, the night sky over the chart table.
    let radius = pf * 0.225
    let squircle = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: pf, height: pf),
                                xRadius: radius, yRadius: radius)
    squircle.addClip()
    let grad = NSGradient(colors: [
        NSColor(red: 0.11, green: 0.30, blue: 0.46, alpha: 1),
        NSColor(red: 0.04, green: 0.10, blue: 0.24, alpha: 1),
    ])!
    grad.draw(in: NSRect(x: 0, y: 0, width: pf, height: pf), angle: -75)

    let cx = pf / 2
    let starCenter = NSPoint(x: cx, y: pf * 0.66)

    // Faint compass rings around the star.
    for ringRadius in [pf * 0.26, pf * 0.38] {
        let ring = NSBezierPath(ovalIn: NSRect(
            x: starCenter.x - ringRadius, y: starCenter.y - ringRadius,
            width: ringRadius * 2, height: ringRadius * 2))
        ring.lineWidth = max(1, pf * 0.008)
        NSColor.white.withAlphaComponent(0.08).setStroke()
        ring.stroke()
    }

    // Open almanac pages along the bottom.
    let pageWhite = NSColor(red: 0.97, green: 0.97, blue: 0.94, alpha: 1)
    let y0 = pf * 0.16
    let spineTop = NSPoint(x: cx, y: pf * 0.38)
    let spineBottom = NSPoint(x: cx, y: y0)

    func page(mirrored: Bool) -> NSBezierPath {
        func x(_ v: CGFloat) -> CGFloat { mirrored ? pf - v : v }
        let path = NSBezierPath()
        path.move(to: spineTop)
        path.curve(to: NSPoint(x: x(pf * 0.17), y: pf * 0.44),
                   controlPoint1: NSPoint(x: x(cx - pf * 0.11), y: pf * 0.44),
                   controlPoint2: NSPoint(x: x(pf * 0.25), y: pf * 0.45))
        path.line(to: NSPoint(x: x(pf * 0.17), y: pf * 0.22))
        path.curve(to: spineBottom,
                   controlPoint1: NSPoint(x: x(pf * 0.25), y: pf * 0.20),
                   controlPoint2: NSPoint(x: x(cx - pf * 0.11), y: pf * 0.19))
        path.close()
        return path
    }

    pageWhite.setFill()
    page(mirrored: false).fill()
    page(mirrored: true).fill()

    // Spine crease.
    let spine = NSBezierPath()
    spine.move(to: spineBottom)
    spine.line(to: spineTop)
    spine.lineWidth = max(1, pf * 0.012)
    NSColor(red: 0.08, green: 0.16, blue: 0.30, alpha: 0.35).setStroke()
    spine.stroke()

    // Faint entry rules on each page — the almanac's columns of figures.
    let ruleColor = NSColor(red: 0.10, green: 0.22, blue: 0.38, alpha: 0.30)
    ruleColor.setStroke()
    for (i, ry) in [pf * 0.335, pf * 0.29].enumerated() {
        let inset = CGFloat(i) * pf * 0.01
        for mirrored in [false, true] {
            func x(_ v: CGFloat) -> CGFloat { mirrored ? pf - v : v }
            let rule = NSBezierPath()
            rule.move(to: NSPoint(x: x(pf * 0.23 + inset), y: ry))
            rule.line(to: NSPoint(x: x(pf * 0.44), y: ry + pf * 0.012))
            rule.lineWidth = max(1, pf * 0.011)
            rule.stroke()
        }
    }

    // Gold compass star: a rotated echo behind, the main star in front.
    let gold = NSColor(red: 0.96, green: 0.79, blue: 0.38, alpha: 1)
    gold.withAlphaComponent(0.55).setFill()
    starPath(center: starCenter, longRadius: pf * 0.095, shortRadius: pf * 0.035,
             rotation: .pi / 4).fill()
    gold.setFill()
    starPath(center: starCenter, longRadius: pf * 0.155, shortRadius: pf * 0.052).fill()

    // Two pinprick stars for company.
    NSColor.white.withAlphaComponent(0.85).setFill()
    NSBezierPath(ovalIn: NSRect(x: pf * 0.24 - pf * 0.012, y: pf * 0.80 - pf * 0.012,
                                width: pf * 0.024, height: pf * 0.024)).fill()
    NSColor.white.withAlphaComponent(0.65).setFill()
    NSBezierPath(ovalIn: NSRect(x: pf * 0.76 - pf * 0.009, y: pf * 0.58 - pf * 0.009,
                                width: pf * 0.018, height: pf * 0.018)).fill()

    return rep.representation(using: .png, properties: [:])
}

for (name, px) in sizes {
    guard let data = makePNG(size: px) else { continue }
    try data.write(to: iconset.appendingPathComponent("\(name).png"))
}

let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconset.path, "-o", here.appendingPathComponent("AppIcon.icns").path]
try proc.run()
proc.waitUntilExit()
print("Wrote AppIcon.icns")
