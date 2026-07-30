import Foundation
import InterviewAssistantCore

enum DisplayNameTests {
    static let all = [
        TestCase(name: "产品名称为面试助手") {
            try expect(
                InterviewAssistantCore.displayName == "面试助手",
                "产品名称应该是“面试助手”"
            )
        },
        TestCase(name: "应用包含正式图标资源") {
            let resources = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources", isDirectory: true)
            let plistData = try Data(
                contentsOf: resources.appendingPathComponent("Info.plist")
            )
            let plist = try PropertyListSerialization.propertyList(
                from: plistData,
                format: nil
            ) as? [String: Any]
            try expect(
                plist?["CFBundleIconFile"] as? String == "AppIcon",
                "Info.plist 必须声明 AppIcon"
            )
            try expect(
                FileManager.default.fileExists(
                    atPath: resources
                        .appendingPathComponent("AppIcon.icns").path
                ),
                "必须包含 AppIcon.icns"
            )
        }
    ]
}
