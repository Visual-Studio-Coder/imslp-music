import AppKit
import Foundation
let root = URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/Resources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1024,pixelsHigh:1024,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
let bounds = NSRect(x:0,y:0,width:1024,height:1024)
NSColor(calibratedRed:0.72,green:0.10,blue:0.20,alpha:1).setFill()
NSBezierPath(rect:bounds).fill()
NSGradient(starting:NSColor(calibratedRed:0.91,green:0.25,blue:0.30,alpha:1),ending:NSColor(calibratedRed:0.55,green:0.05,blue:0.17,alpha:1))!.draw(in:bounds,angle:-50)
NSColor.white.withAlphaComponent(0.12).setStroke()
for n in 0..<6 { let r = CGFloat(160+n*65); let p = NSBezierPath(ovalIn:NSRect(x:760-r,y:680-r,width:r*2,height:r*2)); p.lineWidth = 3; p.stroke() }
let staff = NSBezierPath(); staff.lineWidth = 7
for n in 0..<5 { staff.move(to:NSPoint(x:190,y:310+CGFloat(n)*60)); staff.line(to:NSPoint(x:830,y:400+CGFloat(n)*60)) }
NSColor.white.withAlphaComponent(0.3).setStroke(); staff.stroke()
let note = NSBezierPath(); note.move(to:NSPoint(x:440,y:305)); note.line(to:NSPoint(x:440,y:695)); note.line(to:NSPoint(x:716,y:755)); note.line(to:NSPoint(x:716,y:368)); note.lineWidth = 36; note.lineCapStyle = .round
NSColor.white.setStroke(); note.stroke()
NSColor.white.setFill(); NSBezierPath(ovalIn:NSRect(x:305,y:233,width:152,height:110)).fill(); NSBezierPath(ovalIn:NSRect(x:580,y:295,width:152,height:110)).fill()
NSGraphicsContext.restoreGraphicsState()
let rep = bitmap
let image = NSImage(cgImage:bitmap.cgImage!,size:NSSize(width:1024,height:1024))
try rep.representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent("icon-1024.png"))
var entries:[[String:Any]] = [["idiom":"universal","platform":"ios","size":"1024x1024","filename":"icon-1024.png"]]
for size in [16,32,128,256,512] {
 for scale in [1,2] {
  let pixels = size*scale
  let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels,pixelsHigh:pixels,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
  NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
  image.draw(in:NSRect(x:0,y:0,width:pixels,height:pixels)); NSGraphicsContext.restoreGraphicsState()
  let name = "mac-\(size)-\(scale).png"; try bitmap.representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent(name))
  entries.append(["idiom":"mac","size":"\(size)x\(size)","scale":"\(scale)x","filename":name])
 }
}
let data = try JSONSerialization.data(withJSONObject:["images":entries,"info":["author":"xcode","version":1]],options:[.prettyPrinted,.sortedKeys])
try data.write(to:root.appendingPathComponent("Contents.json"))
