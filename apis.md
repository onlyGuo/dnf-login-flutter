# 登录
POST https://dnf.cv58.xyz/api/v1/client/login
请求:
{
    "accountname": "xxx",
    "password": "xxx"
}

# 注册
POST https://dnf.cv58.xyz/api/v1/client/register
请求:
{
    "accountname": "xxx",
    "password": "xxx",
    "validationIndex": "UUID",
    "valicode": "xxx",
    "recommender": "xxx"
}

# 验证码
GET https://dnf.cv58.xyz/api/v1/vc/img/{UUID}
返回图片

# 获取版本信息
GET https://dnf.cv58.xyz/api/v1/client/version
响应:
{
    "version": "1.0.0",
    "downloadUrl": "https://dnf.cv58.xyz/version/downloads/upload.zip",
    "description": "更新内容说明, MD格式"
}
与当前目录下version.json做对比, 如果没有文件或者没有版本号或者文件无法解析或者版本号不同, 则自动更新.
更新时展示进度条, 更新过程中禁止其他操作.文件下载下来后, 解压覆盖到当前目录, 然后在当前目录的version.json写入版本号.

# 登录器展示大图列表
GET https://dnf.cv58.xyz/api/v1/client/big-pic-list
响应:
[
    {
        "id": 1,
        "title": "标题",
        "imageUrl": "https://dnf.cv58.xyz/images/big1.jpg"
    },
    ...
]
