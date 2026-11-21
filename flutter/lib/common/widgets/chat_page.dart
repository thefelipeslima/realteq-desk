import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/realteq/i18n.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/chat_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../mobile/pages/home_page.dart';

enum ChatPageType {
  mobileMain,
  desktopCM,
}

class ChatPage extends StatelessWidget implements PageShape {
  late final ChatModel chatModel;
  final ChatPageType? type;

  ChatPage({ChatModel? chatModel, this.type}) {
    this.chatModel = chatModel ?? gFFI.chatModel;
  }

  @override
  final title = translate("Chat");

  @override
  final icon = unreadTopRightBuilder(gFFI.chatModel.mobileUnreadSum);

  @override
  final appBarActions = [
    PopupMenuButton<MessageKey>(
        tooltip: "",
        icon: unreadTopRightBuilder(gFFI.chatModel.mobileUnreadSum,
            icon: Icon(Icons.group)),
        itemBuilder: (context) {
          // only mobile need [appBarActions], just bind gFFI.chatModel
          final chatModel = gFFI.chatModel;
          return chatModel.messages.entries.map((entry) {
            final key = entry.key;
            final user = entry.value.chatUser;
            final client = gFFI.serverModel.clients
                .firstWhereOrNull((e) => e.id == key.connId);
            final connected =
                gFFI.serverModel.clients.any((e) => e.id == key.connId);
            return PopupMenuItem<MessageKey>(
              child: Row(
                children: [
                  Icon(
                          key.isOut
                              ? Icons.call_made_rounded
                              : Icons.call_received_rounded,
                          color: MyTheme.accent)
                      .marginOnly(right: 6),
                  Text("${user.firstName}   ${user.id}"),
                  if (connected)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.fromARGB(255, 46, 205, 139)),
                    ).marginSymmetric(horizontal: 2),
                  if (client != null)
                    unreadMessageCountBuilder(client.unreadChatMessageCount)
                        .marginOnly(left: 4)
                ],
              ),
              value: key,
            );
          }).toList();
        },
        onSelected: (key) {
          gFFI.chatModel.changeCurrentKey(key);
        })
  ];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: chatModel,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Consumer<ChatModel>(
          builder: (context, chatModel, child) {
            final readOnly = type == ChatPageType.mobileMain &&
                    (chatModel.currentKey.connId == ChatModel.clientModeID ||
                        gFFI.serverModel.clients.every((e) =>
                            e.id != chatModel.currentKey.connId ||
                            chatModel.currentUser == null)) ||
                type == ChatPageType.desktopCM &&
                    gFFI.serverModel.clients
                            .firstWhereOrNull(
                                (e) => e.id == chatModel.currentKey.connId)
                            ?.disconnected ==
                        true;
            final other = chatModel.currentUser?.firstName ?? '';
            final connected = !readOnly;
            return Column(children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: Color(0xFF2A251A),
                    border: Border(bottom: BorderSide(color: Color(0xFF332E22)))),
                child: Row(children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: connected ? Color(0xFF3BB273) : Colors.grey)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        other.isEmpty ? tr('Conversa') : (rtEn ? 'Chat with $other' : 'Conversa com $other'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Color(0xFFF3EAD8),
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ),
                  Text(connected ? tr('conectado') : tr('desconectado'),
                      style: TextStyle(color: Color(0xFF9B917A), fontSize: 12)),
                ]),
              ),
              Expanded(
                  child: Stack(
              children: [
                LayoutBuilder(builder: (context, constraints) {
                  final chat = DashChat(
                    onSend: chatModel.send,
                    currentUser: chatModel.me,
                    messages: chatModel
                            .messages[chatModel.currentKey]?.chatMessages ??
                        [],
                    readOnly: readOnly,
                    inputOptions: InputOptions(
                      focusNode: chatModel.inputNode,
                      textController: chatModel.textController,
                      inputTextStyle: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.titleLarge?.color),
                      inputDecoration: InputDecoration(
                        isDense: true,
                        hintText: translate('Write a message'),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.background,
                        contentPadding: EdgeInsets.all(10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: const BorderSide(
                            width: 1,
                            style: BorderStyle.solid,
                          ),
                        ),
                      ),
                      sendButtonBuilder: defaultSendButton(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        color: MyTheme.accent,
                        icon: Icons.send_rounded,
                      ),
                    ),
                    messageOptions: MessageOptions(
                      showOtherUsersAvatar: false,
                      showOtherUsersName: true,
                      textColor: Colors.white,
                      maxWidth: constraints.maxWidth * 0.7,
                      messageTextBuilder: (message, _, __) {
                        final isOwnMessage = message.user.id.isBlank!;
                        return Column(
                          crossAxisAlignment: isOwnMessage
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: <Widget>[
                            if (isOwnMessage)
                              Text(tr('Você'),
                                  style: TextStyle(
                                      color: Color(0xFF241B00),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            Text(message.text,
                                style: TextStyle(
                                    color: isOwnMessage
                                        ? Color(0xFF241B00)
                                        : Color(0xFFF3EAD8))),
                            Text(
                              "${message.createdAt.hour}:${message.createdAt.minute.toString().padLeft(2, '0')}",
                              style: TextStyle(
                                color: isOwnMessage
                                    ? Color(0xFF5A4300)
                                    : Color(0xFF9B917A),
                                fontSize: 10,
                              ),
                            ).marginOnly(top: 3),
                          ],
                        );
                      },
                      messageDecorationBuilder:
                          (message, previousMessage, nextMessage) {
                        final isOwnMessage = message.user.id.isBlank!;
                        return defaultMessageDecoration(
                          color: isOwnMessage
                              ? Color(0xFFE6A800)
                              : Color(0xFF2A251A),
                          borderTopLeft: 8,
                          borderTopRight: 8,
                          borderBottomRight: isOwnMessage ? 2 : 8,
                          borderBottomLeft: isOwnMessage ? 8 : 2,
                        );
                      },
                    ),
                  ).workaroundFreezeLinuxMint();
                  return SelectionArea(child: chat);
                }),
              ],
            ).paddingOnly(bottom: 8)),
            ]);
          },
        ),
      ),
    );
  }
}
