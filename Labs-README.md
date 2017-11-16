# Azure Resource Manager QuickStart Templates.

this repo is based on https://github.com/Azure/azure-quickstart-templates
, we extend the repo to support auto-generate without fill parameters mannaly.

## Structure

更新参数文件，修改参数为动态替换模版字符串，如下所示。

labs-azuredeploy.parameters.json

DNS：%{dnsLabelPrefix}%

KEY：%{sshRSAPublicKey}%

PASSWORD：%{adminPassword}%

## Deploying Samples

### 使用Powershell脚本完成创建

待更新

### 使用TFS完成环境创建

所需变量：envFolder
变量值：环境文件夹名称，例如：101-vm-simple-linux



