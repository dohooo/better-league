import AppKit
import CoreGraphics

// ---------- private SkyLight/CGS symbols (detection only) ----------
private let skyHandle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
private func resolveSymbol(_ names: [String]) -> UnsafeMutableRawPointer? {
    for n in names {
        if let h = skyHandle, let s = dlsym(h, n) { return s }
        if let s = dlsym(dlopen(nil, RTLD_NOW), n) { return s }
    }
    return nil
}
typealias CursorSeedFn = @convention(c) () -> Int32
typealias MainConnFn = @convention(c) () -> UInt32
typealias CursorDataSizeFn = @convention(c) (UInt32, UnsafeMutablePointer<Int32>) -> Int32
typealias CursorDataFn = @convention(c) (
    UInt32, UnsafeMutableRawPointer, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>,
    UnsafeMutablePointer<CGRect>, UnsafeMutablePointer<CGPoint>,
    UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>
) -> Int32

private let mainConnFn = resolveSymbol(["SLSMainConnectionID", "CGSMainConnectionID"]).map { unsafeBitCast($0, to: MainConnFn.self) }
private let cursorSeedFn = resolveSymbol(["SLSCurrentCursorSeed", "CGSCurrentCursorSeed"]).map { unsafeBitCast($0, to: CursorSeedFn.self) }
private let cursorDataSizeFn = resolveSymbol(["SLSGetGlobalCursorDataSize", "CGSGetGlobalCursorDataSize"]).map { unsafeBitCast($0, to: CursorDataSizeFn.self) }
private let cursorDataFn = resolveSymbol(["SLSGetGlobalCursorData", "CGSGetGlobalCursorData"]).map { unsafeBitCast($0, to: CursorDataFn.self) }
private let cgsConnection: UInt32 = mainConnFn?() ?? 0

// ---------- cursor classification via pixel grab ----------
enum CursorClass { case big, small, none }

func cursorAPIsAvailable() -> Bool {
    cursorSeedFn != nil && cursorDataSizeFn != nil && cursorDataFn != nil && cgsConnection != 0
}

func currentCursorSeed() -> Int32 { cursorSeedFn?() ?? -1 }
func classifyCursor() -> (cls: CursorClass, desc: String) {
    guard let sizeFn = cursorDataSizeFn, let dataFn = cursorDataFn, cgsConnection != 0 else { return (.none, "unavailable") }
    var dataSize: Int32 = 0
    guard sizeFn(cgsConnection, &dataSize) == 0, dataSize > 0 else { return (.none, "none") }
    var buf = [UInt8](repeating: 0, count: Int(dataSize))
    var size = dataSize
    var rowBytes: Int32 = 0
    var rect = CGRect.zero
    var hotSpot = CGPoint.zero
    var depth: Int32 = 0, components: Int32 = 0, bpc: Int32 = 0
    let err = buf.withUnsafeMutableBytes { ptr -> Int32 in
        dataFn(cgsConnection, ptr.baseAddress!, &size, &rowBytes, &rect, &hotSpot, &depth, &components, &bpc)
    }
    guard err == 0, rect.width > 0 else { return (.none, "none") }
    let desc = "\(Int(rect.width))x\(Int(rect.height))"
    return (rect.width >= 40 || rect.height >= 48 ? .big : .small, desc)
}
