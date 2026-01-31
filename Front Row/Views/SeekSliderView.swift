//
//  SeekSliderView.swift
//  Front Row
//
//  Created by Joshua Park on 3/26/24.
//

import SwiftUI

struct SeekSliderView: NSViewRepresentable {
    typealias NSViewType = SeekSlider

    @Binding var value: Double
    var maxValue: Double

    class SeekSlider: NSSlider {
        override class var cellClass: AnyClass? {
            get {
                return SeekSliderView.SeekSliderCell.self
            }
            set {
                super.cellClass = SeekSliderView.SeekSliderCell.self
            }
        }
    }

    class SeekSliderCell: NSSliderCell {
        override var knobThickness: CGFloat {
            return knobWidth
        }

        let knobWidth: CGFloat = 3
        let knobHeight: CGFloat = 15
        let knobRadius: CGFloat = 1
        let barRadius: CGFloat = 1.5

        var wasPausedBeforeSeeking = false

        override func drawBar(inside rect: NSRect, flipped: Bool) {
            /// The position of the knob, rounded for cleaner drawing
            let knobPos: CGFloat = round(knobRect(flipped: flipped).origin.x)

            /// How far progressed the current video is, used for drawing the bar background
            let progress = knobPos

            NSGraphicsContext.saveGraphicsState()
            let barRect = rect
            let path = NSBezierPath(roundedRect: barRect, xRadius: barRadius, yRadius: barRadius)

            /// draw left
            let pathLeftRect: NSRect = NSMakeRect(
                barRect.origin.x, barRect.origin.y, progress, barRect.height)
            NSBezierPath(rect: pathLeftRect).addClip()

            path.append(
                NSBezierPath(
                    rect: NSRect(
                        x: knobPos - 1, y: barRect.origin.y, width: knobWidth + 2,
                        height: barRect.height)
                ).reversed)

            NSColor.white.withAlphaComponent(0.3).setFill()
            path.fill()
            NSGraphicsContext.restoreGraphicsState()

            /// draw right
            NSGraphicsContext.saveGraphicsState()
            let pathRight = NSMakeRect(
                barRect.origin.x + progress, barRect.origin.y, barRect.width - progress,
                barRect.height)
            NSBezierPath(rect: pathRight).setClip()
            NSColor.white.withAlphaComponent(0.1).setFill()
            path.fill()

            NSGraphicsContext.restoreGraphicsState()
        }

        override func drawKnob(_ knobRect: NSRect) {
            let rect = NSMakeRect(
                round(knobRect.origin.x),
                knobRect.origin.y + 0.5 * (knobRect.height - knobHeight),
                knobRect.width,
                knobHeight)
            let path = NSBezierPath(roundedRect: rect, xRadius: knobRadius, yRadius: knobRadius)
            NSColor.white.withAlphaComponent(0.7).setFill()
            path.fill()
        }

        override func knobRect(flipped: Bool) -> NSRect {
            let slider = self.controlView as! NSSlider
            let barRect = barRect(flipped: flipped)
            var percentage = slider.doubleValue / (slider.maxValue - slider.minValue)
            if percentage.isNaN {
                percentage = 0.0
            }
            /// The usable width of the bar is reduced by the width of the knob.
            let effectiveBarWidth = barRect.width - knobWidth
            let pos = barRect.origin.x + CGFloat(percentage) * effectiveBarWidth
            let rect = super.knobRect(flipped: flipped)

            let height = (barRect.origin.y - rect.origin.y) * 2 + barRect.height
            return NSMakeRect(pos, rect.origin.y, knobWidth, height)
        }

        override func startTracking(at startPoint: NSPoint, in controlView: NSView) -> Bool {
            wasPausedBeforeSeeking = PlayEngine.shared.timeControlStatus == .paused
            let result = super.startTracking(at: startPoint, in: controlView)
            if result {
                PlayEngine.shared.pause()
            }
            return result
        }

        override func stopTracking(
            last lastPoint: NSPoint,
            current stopPoint: NSPoint,
            in controlView: NSView,
            mouseIsUp flag: Bool
        ) {
            if !wasPausedBeforeSeeking {
                PlayEngine.shared.play()
            }
            super.stopTracking(
                last: lastPoint,
                current: stopPoint,
                in: controlView,
                mouseIsUp: flag)
        }
    }

    @MainActor
    class Coordinator: NSObject {
        var seekSlider: SeekSliderView

        init(_ slider: SeekSliderView) {
            self.seekSlider = slider
        }

        @objc func valueChanged(_ sender: SeekSlider) {
            seekSlider.value = sender.doubleValue
        }
    }

    func makeNSView(context: Context) -> SeekSlider {
        let slider = SeekSlider(
            value: value,
            minValue: 0,
            maxValue: maxValue,
            target: context.coordinator,
            action: #selector(Coordinator.valueChanged))
        return slider
    }

    func updateNSView(_ nsView: SeekSlider, context: Context) {
        nsView.maxValue = maxValue
        nsView.doubleValue = value
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}
