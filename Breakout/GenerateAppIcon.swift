#!/usr/bin/swift

import Foundation
import AppKit
import UniformTypeIdentifiers

// アイコンのサイズ
let iconSizes = [16, 32, 128, 256, 512, 1024]

// アイコンを生成する関数
func generateIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    
    image.lockFocus()
    
    // 背景色
    NSColor(red: 0.12, green: 0.13, blue: 0.14, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), 
                 xRadius: CGFloat(size) * 0.18, 
                 yRadius: CGFloat(size) * 0.18).fill()
    
    // ブロックの色
    let blockColors: [NSColor] = [
        NSColor(red: 1.0, green: 0.27, blue: 0.27, alpha: 1.0), // 赤
        NSColor(red: 1.0, green: 0.53, blue: 0.27, alpha: 1.0), // オレンジ
        NSColor(red: 1.0, green: 0.83, blue: 0.27, alpha: 1.0), // 黄色
        NSColor(red: 0.57, green: 1.0, blue: 0.27, alpha: 1.0), // 緑
        NSColor(red: 0.27, green: 1.0, blue: 1.0, alpha: 1.0),  // シアン
        NSColor(red: 0.27, green: 0.46, blue: 1.0, alpha: 1.0), // 青
        NSColor(red: 0.59, green: 0.27, blue: 1.0, alpha: 1.0), // 紫
        NSColor(red: 1.0, green: 0.27, blue: 0.71, alpha: 1.0)  // ピンク
    ]
    
    // 相対的なサイズ計算
    let blockWidth = CGFloat(size) * 0.1
    let blockHeight = CGFloat(size) * 0.05
    let blockCornerRadius = CGFloat(size) * 0.005
    let blockMargin = CGFloat(size) * 0.01
    let blockStartX = CGFloat(size) * 0.17
    let blockStartY = CGFloat(size) * 0.83 - blockHeight * 4 - blockMargin * 3
    
    // ブロックを描画
    for row in 0..<4 {
        for col in 0..<6 {
            let x = blockStartX + CGFloat(col) * (blockWidth + blockMargin)
            let y = blockStartY + CGFloat(row) * (blockHeight + blockMargin)
            
            let colorIndex = (row + col) % blockColors.count
            blockColors[colorIndex].setFill()
            
            NSBezierPath(roundedRect: NSRect(x: x, y: y, width: blockWidth, height: blockHeight), 
                         xRadius: blockCornerRadius, 
                         yRadius: blockCornerRadius).fill()
        }
    }
    
    // ボールを描画（白）
    NSColor.white.setFill()
    let ballRadius = CGFloat(size) * 0.04
    let ballX = CGFloat(size) * 0.5
    let ballY = CGFloat(size) * 0.5
    
    NSBezierPath(ovalIn: NSRect(x: ballX - ballRadius, 
                               y: ballY - ballRadius, 
                               width: ballRadius * 2, 
                               height: ballRadius * 2)).fill()
    
    // 残像効果
    NSColor.white.withAlphaComponent(0.6).setFill()
    let trailRadius1 = ballRadius * 0.9
    NSBezierPath(ovalIn: NSRect(x: ballX - trailRadius1, 
                               y: ballY - ballRadius * 1.5, 
                               width: trailRadius1 * 2, 
                               height: trailRadius1 * 2)).fill()
    
    NSColor.white.withAlphaComponent(0.3).setFill()
    let trailRadius2 = ballRadius * 0.75
    NSBezierPath(ovalIn: NSRect(x: ballX - trailRadius2, 
                               y: ballY - ballRadius * 2.5, 
                               width: trailRadius2 * 2, 
                               height: trailRadius2 * 2)).fill()
    
    // パドルを描画
    let paddleWidth = CGFloat(size) * 0.3
    let paddleHeight = CGFloat(size) * 0.025
    let paddleX = CGFloat(size) * 0.5 - paddleWidth * 0.5
    let paddleY = CGFloat(size) * 0.25
    
    // パドルのグラデーション
    let paddleGradient = NSGradient(colors: [
        NSColor(red: 0.23, green: 0.56, blue: 0.84, alpha: 1.0),
        NSColor(red: 0.37, green: 0.73, blue: 1.0, alpha: 1.0),
        NSColor(red: 0.23, green: 0.56, blue: 0.84, alpha: 1.0)
    ])
    
    let paddlePath = NSBezierPath(roundedRect: NSRect(x: paddleX, 
                                                     y: paddleY, 
                                                     width: paddleWidth, 
                                                     height: paddleHeight), 
                                 xRadius: paddleHeight * 0.5, 
                                 yRadius: paddleHeight * 0.5)
    
    paddleGradient?.draw(in: paddlePath, angle: 0)
    
    image.unlockFocus()
    return image
}

// アイコンを保存する関数
func saveIcon(image: NSImage, size: Int, path: String) {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("Failed to convert NSImage to CGImage for size \(size)")
        return
    }
    
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG data for size \(size)")
        return
    }
    
    do {
        try data.write(to: URL(fileURLWithPath: path))
        print("Saved icon: \(path)")
    } catch {
        print("Failed to save icon at \(path): \(error)")
    }
}

// ディレクトリを作成
let appIconsetPath = "Assets.xcassets/AppIcon.appiconset"
let appiconDir = FileManager.default.currentDirectoryPath + "/" + appIconsetPath

// 各サイズのアイコンを生成して保存
for size in iconSizes {
    let icon = generateIcon(size: size)
    saveIcon(image: icon, size: size, path: "\(appiconDir)/icon_\(size)x\(size).png")
    
    // Retinaディスプレイ用の2倍サイズも生成（512x512@2xは1024x1024と同じ）
    if size < 512 {
        saveIcon(image: icon, size: size * 2, path: "\(appiconDir)/icon_\(size)x\(size)@2x.png")
    } else {
        let linkPath = "\(appiconDir)/icon_\(size)x\(size)@2x.png"
        if FileManager.default.fileExists(atPath: linkPath) == false {
            try? FileManager.default.createSymbolicLink(
                atPath: linkPath,
                withDestinationPath: "icon_1024x1024.png")
            print("Created symbolic link for \(linkPath)")
        }
    }
}

print("App icons generated successfully!") 