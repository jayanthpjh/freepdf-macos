import AppKit
import FreePDFCore

extension EditorWindowController {
    func batch(_ operation: BatchPDF.Operation) throws {
        let inputs = Dialogs.open(types: [.pdf], multiple: true)
        guard !inputs.isEmpty else { return }
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.prompt = "Choose output folder"
        guard panel.runModal() == .OK, let parent = panel.url else { return }
        let folder = parent.appendingPathComponent("FreePDF-batch-\(UUID().uuidString.prefix(8))", isDirectory: true)
        let progress = Progress(totalUnitCount: Int64(inputs.count)); job = progress
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.updateStatus() } }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try BatchPDF.run(inputs: inputs, folder: folder, operation: operation, progress: progress) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.progressTimer?.invalidate(); self.progressTimer = nil; self.job = nil; self.updateStatus()
                switch result {
                case .success(let outcomes):
                    let report = outcomes.map { "\($0.input.lastPathComponent): \($0.error ?? "Saved \($0.output?.lastPathComponent ?? "")")" }.joined(separator: "\n")
                    do { try Data((report + (progress.isCancelled ? "\nCancelled. Completed outputs were kept." : "")).utf8).write(to: folder.appendingPathComponent("Report.txt"), options: .atomic) }
                    catch { Dialogs.error(error) }
                    NSWorkspace.shared.open(folder)
                case .failure(let error): Dialogs.error(error)
                }
            }
        }
    }
}
