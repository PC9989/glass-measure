import SwiftUI
import UIKit

enum Theme {
    static let teal = Color("AccentColor")
    static let ink = Color(red: 0.09, green: 0.16, blue: 0.17)
    static let amber = Color(red: 0.62, green: 0.36, blue: 0.02)
    static let estimate = Color(red: 0.55, green: 0.28, blue: 0.02)
    static let pending = Color(red: 0.18, green: 0.34, blue: 0.48)
    static let measured = Color("AccentColor")

    static let pdfTeal = UIColor(red: 0.055, green: 0.365, blue: 0.380, alpha: 1)
    static let pdfInk = UIColor(red: 0.09, green: 0.14, blue: 0.15, alpha: 1)
    static let pdfMuted = UIColor(red: 0.33, green: 0.36, blue: 0.36, alpha: 1)
    static let pdfPaper = UIColor(red: 0.985, green: 0.982, blue: 0.972, alpha: 1)
    static let pdfAmber = UIColor(red: 0.55, green: 0.32, blue: 0.02, alpha: 1)
    static let pdfRule = UIColor(red: 0.82, green: 0.84, blue: 0.83, alpha: 1)
    static let pdfRow = UIColor(red: 0.945, green: 0.955, blue: 0.953, alpha: 1)
}

enum Copy {
    static let appName = "玻璃度尺"
    static let subtitle = "Glass Measure"
    static let jobs = "工作"
    static let newJob = "新工作"
    static let customer = "客戶／地盤"
    static let customerPlaceholder = "例如：中環皇后大道中 88 號"
    static let notes = "備註"
    static let notesPlaceholder = "樓層、單位、窗的位置"
    static let unnamedSite = "未命名地盤"
    static let save = "儲存"
    static let cancel = "取消"
    static let delete = "刪除"
    static let done = "完成"
    static let close = "關閉"
    static let width = "寬度"
    static let height = "高度"
    static let diagonal = "對角線"
    static let area = "面積"
    static let totalArea = "總面積"
    static let glass = "玻璃"
    static let frame = "窗框"
    static let addGlass = "加入玻璃"
    static let measureAR = "擴增實境量度"
    static let measurePhoto = "照片估算"
    static let measureManual = "手動輸入尺寸"
    static let startMeasure = "開始量度"
    static let generatePDF = "產生 PDF 報告"
    static let sharePDF = "分享 PDF"
    static let shareText = "分享文字摘要"
    static let previewTitle = "報告預覽"
    static let pendingSize = "待實尺"
    static let estimate = "估算"
    static let measured = "實測"
    static let ratioCaption = "寬:高"
    static let ratioPreciseCaption = "寬比高"
    static let knownEdge = "已知邊長"
    static let enterKnownEdge = "輸入已知邊長"
    static let changeKnownEdge = "更改已知邊長"
    static let clearKnownEdge = "清除實尺"
    static let savePending = "儲存比例（待實尺）"
    static let saveEstimate = "儲存估算"
    static let tapeCorrect = "拉尺校正"
    static let apply = "套用"
    static let resetPoints = "復位"
    static let placePoint = "落點"
    static let capture = "拍攝標註照片"
    static let retake = "重拍"
    static let savePane = "儲存這塊玻璃"
    static let rectangleMode = "對角"
    static let quadMode = "四角"
    static let showMesh = "顯示網格"
    static let hideMesh = "隱藏網格"
    static let restartTracking = "重新追蹤"
    static let choosePhoto = "選擇窗框相片"
    static let photoLibrary = "從相片圖庫選擇"
    static let photoFiles = "從檔案選擇"
    static let photoCamera = "拍攝靜態照片"
    static let replacePhoto = "換相片"
    static let backOne = "回退一點"
    static let fitPhoto = "實際大小"
    static let noLiDAR = "無 LiDAR · 準確度較低"
    static let hasLiDAR = "LiDAR"
    static let localOnly = "資料只儲存在這部裝置，相片不會上載。"

    static let emptyJobsTitle = "未有量度工作"
    static let emptyJobsMessage = "建立地盤工作後，可用 LiDAR 量度窗框，或在相片上標示比例。完成後產生 PDF 報告。"
    static let emptyPanesTitle = "這份工作尚未有玻璃"
    static let emptyPanesMessage = "用擴增實境對準窗框落點，或上載相片標示四角。未有實尺的相片只會保存比例。"
    static let emptyDetailTitle = "選擇一份工作"
    static let emptyDetailMessage = "左邊是地盤工作。打開後可量度玻璃，並產生報告。"
    static let noSearch = "找不到相符的工作"

    static let glassWarning = "玻璃及反光表面難以直接追蹤。請點選窗框或牆身平面，並以拉尺覆核最少一邊。"
    static let noLiDARWarning = "此裝置沒有 LiDAR，擴增實境準確度較低。建議以拉尺覆核一邊，或改用照片估算。"
    static let photoWarning = "此為照片估算，不是 LiDAR 實測。請盡量正面拍攝窗框；斜拍、廣角或透視變形會令比例偏差，不能當作絕對尺寸。"
    static let pendingExplanation = "未輸入已知邊長，所以不會計算毫米、對角線或面積。可以先儲存比例，稍後補上拉尺讀數。"
    static let pendingPDF = "未輸入已知邊長，故不計算毫米及面積。"
    static let cameraDeniedTitle = "未能使用相機"
    static let cameraDeniedMessage = "擴增實境及拍攝相片需要相機。可到「設定」開啟權限，或改為從圖庫選擇相片、從檔案匯入，或手動輸入尺寸。"
    static let arUnsupportedTitle = "此裝置不支援擴增實境"
    static let arUnsupportedMessage = "仍可從相片估算比例，或手動輸入寬度及高度。不會用假尺寸填補。"
    static let openSettings = "開啟設定"
    static let pdfNeedsPane = "加入玻璃後即可產生報告。"
    static let pdfSavedHint = "報告已儲存在本機。分享頁可傳到「檔案」、WhatsApp、郵件或其他 App。相片不會上載。"
    static let generating = "正在產生報告…"
    static let pdfFailed = "未能產生 PDF 報告。"
    static let retry = "再試一次"

    static func glassTitle(_ index: Int) -> String { "玻璃 \(index)" }
    static func placed(_ count: Int, of total: Int) -> String { "已落 \(count) / \(total) 點" }
    static func pendingPieces(_ count: Int) -> String { "\(count) 塊待實尺" }
    static func pieceCount(_ count: Int) -> String { "\(count) 塊玻璃" }
}
