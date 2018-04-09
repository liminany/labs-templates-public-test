#### 项目介绍

本项目模板使用yoTeam在指定的Team Foundation Server 2018 中自动创建一套基于 Asp.Net Core 的示例程序和持续交付流水线。当推送代码到Git仓库后会触发CI、CD，示例程序最终会部署到Azure App Service 中。

| 创建的内容  | 说明  |
| ------------ | ------------ |
| 团队项目 | 一个TFS Team Project |
| Asp.Net Core 源代码  | 使用Visual Studio 的Asp.Net Core 默认项目模板创建的一套Demo程序 |
| 生成定义：项目名-CI(YoTeamAspDemoApp5049-CI) | 自动创建的生成定义 |
| 发布定义：项目名-CD(YoTeamAspDemoApp5049-CD) | 自动创建的发布定义 |
| Azure 资源管理器(订阅名称)| 通过此通道将程序部署到Azure App Service |


#### ASP.NET Core with App Service CI/CD

![](https://raw.githubusercontent.com/lean-soft/labs-templates/master/lsproj101-yoteam-asp/labs/images/image1.png)
![](https://raw.githubusercontent.com/lean-soft/labs-templates/master/lsproj101-yoteam-asp/labs/images/image2.png)
![](https://raw.githubusercontent.com/lean-soft/labs-templates/master/lsproj101-yoteam-asp/labs/images/image3.png)
![](https://raw.githubusercontent.com/lean-soft/labs-templates/master/lsproj101-yoteam-asp/labs/images/image4.png)
