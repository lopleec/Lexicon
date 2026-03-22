import AppKit
import SwiftUI

struct ReturnSendTextEditor: NSViewRepresentable {
    @Binding var text: String
    let onPasteImage: ([ImageAttachment]) -> Void
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.contentView.postsBoundsChangedNotifications = true

        let initialSize = NSSize(width: max(scrollView.contentSize.width, 1), height: max(scrollView.contentSize.height, 1))
        let textView = SubmitTextView(frame: NSRect(origin: .zero, size: initialSize))
        textView.delegate = context.coordinator
        textView.onSubmit = { [onSubmit, weak coordinator = context.coordinator] in
            coordinator?.pendingClearAfterSubmit = true
            onSubmit()
        }
        textView.onPasteImage = onPasteImage
        textView.string = text
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.font = .systemFont(ofSize: 14, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.insertionPointColor = NSColor.labelColor
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.textContainer?.containerSize = NSSize(width: initialSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? SubmitTextView else { return }
        context.coordinator.parent = self
        textView.onSubmit = { [onSubmit, weak coordinator = context.coordinator] in
            coordinator?.pendingClearAfterSubmit = true
            onSubmit()
        }
        textView.onPasteImage = onPasteImage

        let width = max(nsView.contentSize.width, 1)
        if textView.frame.width != width {
            textView.frame.size.width = width
            textView.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        }

        // Empty binding is authoritative and should always clear the editor, including button-send path.
        if text.isEmpty {
            if !textView.string.isEmpty {
                context.coordinator.applyText("", to: textView)
            }
            context.coordinator.pendingClearAfterSubmit = false
            return
        }

        if context.coordinator.isEditing {
            // While user is actively editing, ignore stale non-empty SwiftUI updates.
            return
        }

        context.coordinator.applyText(text, to: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ReturnSendTextEditor
        var pendingClearAfterSubmit = false
        var isEditing = false
        private var isApplyingProgrammaticText = false

        init(_ parent: ReturnSendTextEditor) {
            self.parent = parent
        }

        func applyText(_ newText: String, to textView: NSTextView) {
            guard textView.string != newText else { return }
            isApplyingProgrammaticText = true
            textView.string = newText
            isApplyingProgrammaticText = false
        }

        func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
        }

        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingProgrammaticText else { return }
            guard let textView = notification.object as? NSTextView else { return }
            if parent.text != textView.string {
                parent.text = textView.string
            }
        }
    }
}

private final class SubmitTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onPasteImage: (([ImageAttachment]) -> Void)?
    private var didAutoFocus = false

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard !didAutoFocus else { return }
        didAutoFocus = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        let returnKey = event.keyCode == 36 || event.keyCode == 76
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasModifier = !modifiers.intersection([.shift, .control, .option, .command]).isEmpty

        if modifiers.contains(.command),
           let characters = event.charactersIgnoringModifiers?.lowercased(),
           characters == "v" {
            if handlePasteImages() {
                return
            }
        }

        if returnKey, !hasModifier, !hasMarkedText() {
            onSubmit?()
            return
        }

        super.keyDown(with: event)
    }

    override func paste(_ sender: Any?) {
        if handlePasteImages() {
            return
        }
        super.paste(sender)
    }

    override func pasteAsPlainText(_ sender: Any?) {
        if handlePasteImages() {
            return
        }
        super.pasteAsPlainText(sender)
    }

    override func pasteAsRichText(_ sender: Any?) {
        if handlePasteImages() {
            return
        }
        super.pasteAsRichText(sender)
    }

    private func handlePasteImages() -> Bool {
        let attachments = ImageAttachment.fromPasteboard(.general)
        guard !attachments.isEmpty else { return false }
        onPasteImage?(attachments)
        return true
    }
}
