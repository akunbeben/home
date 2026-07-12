import CoreGraphics

public enum PlaceholderLayout {
    public static func frames(
        for regions: [CGRect],
        displayFrame: CGRect,
        viewBounds: CGRect
    ) -> [CGRect] {
        guard displayFrame.width > 0,
              displayFrame.height > 0,
              viewBounds.width > 0,
              viewBounds.height > 0
        else { return [] }

        let scale = min(
            viewBounds.width / displayFrame.width,
            viewBounds.height / displayFrame.height
        )
        let renderedSize = CGSize(
            width: displayFrame.width * scale,
            height: displayFrame.height * scale
        )
        let offset = CGPoint(
            x: viewBounds.minX + (viewBounds.width - renderedSize.width) / 2,
            y: viewBounds.minY + (viewBounds.height - renderedSize.height) / 2
        )

        return regions.compactMap { region in
            let clipped = region.intersection(displayFrame)
            guard !clipped.isNull, clipped.width > 1, clipped.height > 1 else { return nil }

            return CGRect(
                x: offset.x + (clipped.minX - displayFrame.minX) * scale,
                y: offset.y + (displayFrame.maxY - clipped.maxY) * scale,
                width: clipped.width * scale,
                height: clipped.height * scale
            )
        }
    }
}
