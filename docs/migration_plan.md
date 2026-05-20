# The Road Of Music 迁移计划

## 迁移原则

1. 使用 Flutter 开发，保持与 1.0 版 uniapp 页面行为一致。
2. 业务状态与 UI 严格分层：`state/controller` 处理状态与业务，`ui` 只负责展示和交互。
3. 每轮开发后必须执行 `flutter analyze` 并保持 0 issue。

## 页面迁移清单

| 路由 | uniapp 页面 | Flutter 状态 |
| --- | --- | --- |
| `/login` | `pages/login/index.vue` | 已完成 |
| `/register` | `pages/login/register.vue` | 已完成 |
| `/forget` | `pages/login/forget.vue` | 已完成 |
| `/xieyi2` | `pages/PersonalCenter/xieyi2.vue` | 已完成（基础版） |
| `/` | `pages/home/index.vue` | 迁移中（占位） |
| `/school` | `pages/home/school.vue` | 待迁移 |
| `/music` | `pages/music/index.vue` | 待迁移 |
| `/courseware` | `pages/courseware/index.vue` | 待迁移 |
| `/video-tutorial` | `pages/VideoTutorial/index.vue` | 待迁移 |
| `/smart-dictation` | `pages/SmartDictation/index.vue` | 待迁移 |
| `/smart-campus` | `pages/SmartCampus/index.vue` | 待迁移 |
| `/smart-campus/sign-records` | `pages/SmartCampus/sign-records.vue` | 待迁移 |
| `/smart-campus/sign-approvals` | `pages/SmartCampus/sign-approvals.vue` | 待迁移 |
| `/smart-singing` | `pages/SmartSinging/index.vue` | 待迁移 |
| `/my-notes` | `pages/MyNotes/index.vue` | 待迁移 |
| `/my-collection` | `pages/MyCollection/index.vue` | 待迁移 |
| `/personal-center` | `pages/PersonalCenter/index.vue` | 待迁移 |
| `/help-feedback` | `pages/HelpFeedback/index.vue` | 待迁移 |
| 其他子页面 | `pages/home/*` `pages/PersonalCenter/*` 等 | 待迁移 |

