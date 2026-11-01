// Derive platform assets from the approved artwork and bundled wordmark font.
import AppKit
import CoreText
import Foundation

let fontURL = URL(fileURLWithPath: "assets/fonts/PatrickHand-Regular.ttf")
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
let font = CTFontCreateWithName("PatrickHand-Regular" as CFString, 300, nil)
let line = CTLineCreateWithAttributedString(NSAttributedString(string: "Shien", attributes: [
    NSAttributedString.Key(kCTFontAttributeName as String): font
]))
let outline = CGMutablePath()
for run in CTLineGetGlyphRuns(line) as! [CTRun] {
    let count = CTRunGetGlyphCount(run)
    var glyphs = [CGGlyph](repeating: 0, count: count)
    var positions = [CGPoint](repeating: .zero, count: count)
    CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
    CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
    for i in 0..<count {
        if let path = CTFontCreatePathForGlyph(font, glyphs[i], nil) {
            outline.addPath(path, transform: CGAffineTransform(translationX: positions[i].x, y: positions[i].y))
        }
    }
}
func color(_ hex: UInt32) -> CGColor {
    CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [
        CGFloat((hex >> 16) & 255)/255, CGFloat((hex >> 8) & 255)/255, CGFloat(hex & 255)/255, 1])!
}
// Keep the approved full-color master intact for conventional app icons.
func loadImage(_ name: String) -> CGImage {
    guard let image = NSImage(contentsOfFile: "assets/app_icon/\(name).png"),
          let result = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("Missing brand source: \(name).png")
    }
    return result
}
let master = loadImage("calendar_master")
let symbol = loadImage("calendar_cutout")
func drawSymbol(_ context: CGContext, _ rect: CGRect) {
    context.interpolationQuality = .high
    context.draw(symbol, in: rect)
}
// A legible one-color calendar/bell companion for Android themed icons.
func drawMonochrome(_ context: CGContext, _ rect: CGRect) {
    context.saveGState()
    context.translateBy(x: rect.minX, y: rect.minY)
    context.scaleBy(x: rect.width / 100, y: rect.height / 100)
    context.setStrokeColor(color(0xFFFFFF))
    context.setFillColor(color(0xFFFFFF))
    context.setLineWidth(5)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.addPath(CGPath(roundedRect: CGRect(x: 12, y: 18, width: 67, height: 64), cornerWidth: 12, cornerHeight: 12, transform: nil))
    context.strokePath()
    for x in [30.0, 61.0] {
        context.move(to: CGPoint(x: x, y: 76)); context.addLine(to: CGPoint(x: x, y: 91))
    }
    context.move(to: CGPoint(x: 14, y: 64)); context.addLine(to: CGPoint(x: 77, y: 64))
    for y in [49.0, 33.0] {
        context.move(to: CGPoint(x: 25, y: y)); context.addLine(to: CGPoint(x: 29, y: y-4)); context.addLine(to: CGPoint(x: 36, y: y+5))
        context.move(to: CGPoint(x: 46, y: y)); context.addLine(to: CGPoint(x: 58, y: y))
    }
    context.strokePath()
    // Clear behind the foreground bell so overlapping outlines remain distinct.
    context.setBlendMode(.clear)
    context.fillEllipse(in: CGRect(x: 59, y: 5, width: 38, height: 44))
    context.setBlendMode(.normal)
    context.move(to: CGPoint(x: 63, y: 16))
    context.addCurve(to: CGPoint(x: 68, y: 32), control1: CGPoint(x: 68, y: 21), control2: CGPoint(x: 67, y: 24))
    context.addCurve(to: CGPoint(x: 88, y: 32), control1: CGPoint(x: 68, y: 46), control2: CGPoint(x: 88, y: 46))
    context.addCurve(to: CGPoint(x: 93, y: 16), control1: CGPoint(x: 89, y: 24), control2: CGPoint(x: 88, y: 21))
    context.closePath(); context.fillPath()
    context.fillEllipse(in: CGRect(x: 74, y: 7, width: 8, height: 8))
    context.restoreGState()
}
func drawWord(_ context: CGContext, center: CGPoint, width: CGFloat, tint: UInt32) {
    let bounds = outline.boundingBoxOfPath
    let scale = width / bounds.width
    context.saveGState()
    context.translateBy(x: center.x - bounds.midX*scale, y: center.y - bounds.midY*scale)
    context.scaleBy(x: scale, y: scale)
    context.setFillColor(color(tint))
    context.addPath(outline)
    context.fillPath()
    context.restoreGState()
}
func render(_ name: String, size: Int, mode: String = "icon", foreground: UInt32 = 0x365C9C, background: UInt32? = nil, height: Int? = nil, destination: String? = nil) throws {
    let canvasHeight = height ?? size
    let context = CGContext(data: nil, width: size, height: canvasHeight, bitsPerComponent: 8,
        bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    if let background = background {
        context.setFillColor(color(background))
        context.fill(CGRect(x: 0, y: 0, width: size, height: canvasHeight))
    }
    let edge = CGFloat(size)
    if mode == "splash" {
        drawSymbol(context, CGRect(x: edge*0.26, y: edge*0.39, width: edge*0.48, height: edge*0.48))
        drawWord(context, center: CGPoint(x: edge/2, y: edge*0.30), width: edge*0.34, tint: foreground)
    } else if mode == "feature" {
        drawSymbol(context, CGRect(x: 362, y: 184, width: 300, height: 300))
        drawWord(context, center: CGPoint(x: 512, y: 115), width: 210, tint: foreground)
    } else if mode == "icon" {
        context.interpolationQuality = .high
        context.draw(master, in: CGRect(x: 0, y: 0, width: edge, height: edge))
    } else {
        let fraction: CGFloat = (mode == "adaptive" || mode == "monochrome") ? 0.70 : 1
        let inset = edge*(1-fraction)/2
        let rect = CGRect(x: inset, y: inset, width: edge*fraction, height: edge*fraction)
        if mode == "monochrome" { drawMonochrome(context, rect) }
        else { drawSymbol(context, rect) }
    }
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination ?? "assets/app_icon/\(name).png"))
}
try render("app_icon", size: 1024, background: 0xF6F7F9)
try render("adaptive_foreground", size: 1024, mode: "adaptive")
try render("adaptive_monochrome", size: 1024, mode: "monochrome")
try render("brand_mark", size: 256, mode: "mark")
try render("splash_icon", size: 512, mode: "splash")
try render("splash_icon_dark", size: 512, mode: "splash", foreground: 0xACC6F4)
try FileManager.default.createDirectory(atPath: "docs/store/assets", withIntermediateDirectories: true)
try render("play-icon", size: 512, background: 0xF6F7F9, destination: "docs/store/assets/play-icon.png")
try render("feature", size: 1024, mode: "feature", background: 0xF6F7F9, height: 500, destination: "docs/store/assets/feature-graphic.png")
