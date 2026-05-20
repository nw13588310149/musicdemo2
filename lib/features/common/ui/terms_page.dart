import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const paragraphs = <String>[
      '为使用本软件及服务，您应当阅读并遵守《本软件许可协议》。请您务必审慎阅读，充分理解各条款内容。',
      '本协议是您与本软件之间关于下载、安装、使用、复制本软件，以及使用本软件相关服务所订立的协议。',
      '您可以从本软件授权渠道获取安装包。若从未授权渠道获取，可能导致软件无法正常使用，本软件不对此承担责任。',
      '为了改善用户体验并提升服务质量，本软件可能不定期提供版本更新。旧版本可能逐步停止支持。',
      '保护用户个人信息是本软件的一项基本原则。除法律法规另有规定外，未经许可不会向第三方披露。',
      '您在使用本服务时应遵守法律法规、社会公序良俗，不得实施违法违规行为。',
      '除非法律允许或书面许可，您不得对本软件进行反向工程、反编译或以其他方式尝试获取源代码。',
      '您应妥善保管账号并对账号下的所有行为负责。使用本软件即视为同意接受本协议约束。',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('用户协议')),
      body: Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemBuilder: (context, index) => Text(
                  paragraphs[index],
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.8,
                    color: Color(0xFF333333),
                  ),
                ),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemCount: paragraphs.length,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 230,
              height: 40,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('我已知晓并同意上述协议'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
