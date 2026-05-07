# Live 模块

直播功能模块，包含直播列表、主播开播准备、主播直播间、观众直播间等页面。

## 文件列表

| 文件 | 职责 |
|------|------|
| `LiveModule.swift` | 模块入口，注册路由与模块初始化 |
| `LiveListViewController.swift` | 直播列表页，支持单列/双列切换，处理悬浮窗逻辑与房间跳转 |
| `LiveListTransitioningDelegate.swift` | 直播列表自定义转场动画，包含 `LiveListPresentationController`、`LiveListPresentAnimation`、`LiveListTransitioningDelegate`，支持 single column 模式下的截图遮罩过渡（转场完成后截图保留在 presented VC 上，等进房成功后才淡出移除） |
| `AnchorPrepareViewController.swift` | 主播开播准备页 |
| `AnchorViewController.swift` | 主播直播间页面 |
| `AudienceViewController.swift` | 观众直播间页面 |
