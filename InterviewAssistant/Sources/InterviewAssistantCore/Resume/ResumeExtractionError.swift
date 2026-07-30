import Foundation

public enum ResumeExtractionError:
    LocalizedError,
    Equatable,
    Sendable
{
    case unsupportedFormat(String)
    case invalidFile
    case noText

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFormat(fileExtension):
            "暂不支持 .\(fileExtension) 简历"
        case .invalidFile:
            "无法读取这个简历文件"
        case .noText:
            "没有识别到有效的简历文字"
        }
    }
}
