import SwiftUI
import UniformTypeIdentifiers

struct CSVFile: FileDocument {
    static var readableContentTypes: [UTType] = [.commaSeparatedText]
    static var writableContentTypes: [UTType] = [.commaSeparatedText, .plainText] // Allow .plainText as fallback

    var text: String

    init(initialText: String = "") {
        self.text = initialText
    }

    // This initializer is required for opening documents, not strictly for saving.
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    // This function is called when saving the document.
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = text.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown) // Or a more specific error
        }
        return FileWrapper(regularFileWithContents: data)
    }
}
