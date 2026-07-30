import Foundation
import InterviewAssistantCore

enum SessionDirectoryStoreTests {
    static let all = [
        TestCase(name: "场次目录包含时间且不会重名") {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            let store = SessionDirectoryStore(root: root)

            let first = try store.createSessionDirectory(
                now: Date(timeIntervalSince1970: 0)
            )
            let second = try store.createSessionDirectory(
                now: Date(timeIntervalSince1970: 0)
            )

            try expect(first != second, "两次创建的目录不能相同")
            try expect(
                FileManager.default.fileExists(atPath: first.path),
                "场次目录应该已经创建"
            )
            try expect(
                first.lastPathComponent.hasPrefix("19700101-080000-"),
                "目录名应该使用上海时区的时间"
            )
        }
    ]
}
