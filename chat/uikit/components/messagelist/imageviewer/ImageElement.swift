import Foundation

struct ImageElement {
    public let type: Int
    let imagePath: String
    let videoPath: String?

    init(type: Int, imagePath: String, videoPath: String? = nil) {
        self.type = type
        self.imagePath = imagePath
        self.videoPath = videoPath
    }
}
