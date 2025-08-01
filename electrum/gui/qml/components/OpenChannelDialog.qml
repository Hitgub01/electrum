import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.electrum 1.0

import "controls"

ElDialog {
    id: root

    title: qsTr("Open Lightning Channel")
    iconSource: Qt.resolvedUrl('../../icons/lightning.png')

    padding: 0

    width: parent.width
    height: parent.height

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Flickable {
            Layout.preferredWidth: parent.width
            Layout.fillHeight: true

            leftMargin: constants.paddingLarge
            rightMargin: constants.paddingLarge

            contentHeight: rootLayout.height
            clip:true
            interactive: height < contentHeight

            GridLayout {
                id: rootLayout
                width: parent.width

                columns: 3

                InfoTextArea {
                    Layout.fillWidth: true
                    Layout.columnSpan: 3
                    visible: !Daemon.currentWallet.lightningHasDeterministicNodeId
                    iconStyle: InfoTextArea.IconStyle.Warn
                    text: Daemon.currentWallet.seedType == 'segwit'
                        ? [ qsTr('Your channels cannot be recovered from seed, because they were created with an old version of Electrum.'), ' ',
                            qsTr('This means that you must save a backup of your wallet every time you create a new channel.'),
                            '\n\n',
                            qsTr('If you want this wallet to have recoverable channels, you must close your existing channels and restore this wallet from seed.')
                          ].join('')
                        : [ qsTr('Your channels cannot be recovered from seed.'), ' ',
                            qsTr('This means that you must save a backup of your wallet every time you create a new channel.'),
                            '\n\n',
                            qsTr('If you want to have recoverable channels, you must create a new wallet with an Electrum seed')
                          ].join('')
                }

                InfoTextArea {
                    Layout.fillWidth: true
                    Layout.columnSpan: 3
                    visible: Daemon.currentWallet.lightningHasDeterministicNodeId && !Config.useRecoverableChannels
                    iconStyle: InfoTextArea.IconStyle.Warn
                    text: [ qsTr('You currently have recoverable channels setting disabled.'),
                            qsTr('This means your channels cannot be recovered from seed.')
                          ].join(' ')
                }

                Label {
                    text: qsTr('Node')
                    Layout.columnSpan: 3
                    color: Material.accentColor
                }

                // gossip
                TextArea {
                    id: node
                    visible: Config.useGossip
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    font.family: FixedFont
                    wrapMode: Text.Wrap
                    placeholderText: qsTr('Paste or scan node uri/pubkey')
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    onTextChanged: {
                        if (activeFocus)
                            channelopener.connectStr = text
                    }
                    onActiveFocusChanged: {
                        if (!activeFocus)
                            channelopener.connectStr = text
                    }
                }

                RowLayout {
                    visible: Config.useGossip
                    spacing: 0
                    ToolButton {
                        icon.source: '../../icons/paste.png'
                        icon.height: constants.iconSizeMedium
                        icon.width: constants.iconSizeMedium
                        onClicked: {
                            var cliptext = AppController.clipboardToText()
                            if (!cliptext)
                                return
                            if (channelopener.validateConnectString(cliptext)) {
                                channelopener.connectStr = cliptext
                                node.text = channelopener.connectStr
                            } else {
                                var dialog = app.messageDialog.createObject(app, {
                                    text: qsTr('Invalid node-id or connect string')
                                })
                                dialog.open()
                            }
                        }
                    }
                    ToolButton {
                        icon.source: '../../icons/qrcode.png'
                        icon.height: constants.iconSizeMedium
                        icon.width: constants.iconSizeMedium
                        scale: 1.2
                        onClicked: {
                            var dialog = app.scanDialog.createObject(app, {
                                hint: qsTr('Scan a node-id or a connect string')
                            })
                            dialog.onFoundText.connect(function(data) {
                                if (channelopener.validateConnectString(data)) {
                                    channelopener.connectStr = data
                                    node.text = channelopener.connectStr
                                } else {
                                    var errdialog = app.messageDialog.createObject(app, {
                                        text: qsTr('Invalid node-id or connect string')
                                    })
                                    errdialog.open()
                                }
                                dialog.close()
                            })
                            dialog.open()
                        }
                    }
                }

                // trampoline
                ComboBox {
                    visible: !Config.useGossip
                    Layout.columnSpan: 3
                    Layout.fillWidth: true
                    model: channelopener.trampolineNodeNames
                    onCurrentValueChanged: {
                        if (activeFocus)
                            channelopener.connectStr = currentValue
                    }
                    // preselect a random node
                    Component.onCompleted: {
                        if (!Config.useGossip) {
                            currentIndex = Math.floor(Math.random() * channelopener.trampolineNodeNames.length)
                            channelopener.connectStr = currentValue
                        }
                    }
                }

                Label {
                    text: qsTr('Amount')
                    Layout.columnSpan: 3
                    color: Material.accentColor
                }

                BtcField {
                    id: amountBtc
                    fiatfield: amountFiat
                    Layout.preferredWidth: amountFontMetrics.advanceWidth('0') * 14 + leftPadding + rightPadding
                    onTextAsSatsChanged: {
                        if (!is_max.checked)
                            channelopener.amount = amountBtc.textAsSats
                    }
                    readOnly: is_max.checked
                    color: readOnly
                        ? Material.accentColor
                        : Material.foreground

                    Connections {
                        target: channelopener.amount
                        function onSatsIntChanged() {
                            if (is_max.checked)  // amount updated by max amount estimate
                                amountBtc.text = Config.formatSatsForEditing(channelopener.amount.satsInt)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: Config.baseUnit
                        color: Material.accentColor
                    }
                    Switch {
                        id: is_max
                        text: qsTr('Max')
                        onCheckedChanged: {
                            if (activeFocus) {
                                channelopener.amount.isMax = checked
                                if (checked) {
                                    channelopener.updateMaxAmount()
                                }
                            }
                        }
                    }
                }

                Item { width: 1; height: 1; visible: Daemon.fx.enabled }

                FiatField {
                    id: amountFiat
                    Layout.preferredWidth: amountFontMetrics.advanceWidth('0') * 14 + leftPadding + rightPadding
                    btcfield: amountBtc
                    visible: Daemon.fx.enabled
                    readOnly: is_max.checked
                    color: readOnly
                        ? Material.accentColor
                        : Material.foreground
                }

                Label {
                    visible: Daemon.fx.enabled
                    text: Daemon.fx.fiatCurrency
                    color: Material.accentColor
                    Layout.fillWidth: true
                }

                Item { visible: Daemon.fx.enabled ; height: 1; width: 1 }

                InfoTextArea {
                    id: warning
                    Layout.topMargin: constants.paddingMedium
                    Layout.fillWidth: true
                    Layout.columnSpan: 3
                    text: channelopener.warning
                    visible: text
                    compact: true
                }

            }
        }

        FlatButton {
            Layout.fillWidth: true
            text: qsTr('Open Channel...')
            icon.source: '../../icons/confirmed.png'
            enabled: channelopener.valid
            onClicked: channelopener.openChannel()
        }
    }

    Component {
        id: confirmOpenChannelDialog
        ConfirmTxDialog {
            amountLabelText: qsTr('Channel capacity')
            sendButtonText: qsTr('Open Channel')
            finalizer: channelopener.finalizer
        }
    }

    ChannelOpener {
        id: channelopener
        wallet: Daemon.currentWallet
        onAuthRequired: (method, authMessage) => {
            app.handleAuthRequired(channelopener, method, authMessage)
        }
        onValidationError: (code, message) => {
            if (code == 'invalid_nodeid') {
                var dialog = app.messageDialog.createObject(app, {
                    title: qsTr('Error'),
                    iconSource: Qt.resolvedUrl('../../icons/warning.png'),
                    text: message
                })
                dialog.open()
            }
        }
        onConflictingBackup: (message) => {
            var dialog = app.messageDialog.createObject(app, {
                text: message,
                yesno: true
            })
            dialog.open()
            dialog.accepted.connect(function() {
                channelopener.openChannel(true)
            })
        }
        onFinalizerChanged: {
            var dialog = confirmOpenChannelDialog.createObject(app, {
                satoshis: channelopener.amount
            })
            dialog.accepted.connect(function() {
                dialog.finalizer.signAndSend()
            })
            dialog.open()
        }
        onChannelOpening: (peer) => {
            console.log('Channel is opening')
            app.channelOpenProgressDialog.reset()
            app.channelOpenProgressDialog.peer = peer
            app.channelOpenProgressDialog.open()
        }
        onChannelOpenError: (message) => {
            app.channelOpenProgressDialog.state = 'failed'
            app.channelOpenProgressDialog.error = message
        }
        onChannelOpenSuccess: (cid, has_onchain_backup, min_depth, tx_complete) => {
            var message = qsTr('Channel established.') + ' '
                    + qsTr('This channel will be usable after %1 confirmations').arg(min_depth)
            if (!tx_complete) {
                message = message + '\n\n' + qsTr('Please sign and broadcast the funding transaction.')
                channelopener.wallet.historyModel.initModel(true) // local tx doesn't trigger model update
            }
            app.channelOpenProgressDialog.state = 'success'
            app.channelOpenProgressDialog.info = message
            if (!has_onchain_backup) {
                app.channelOpenProgressDialog.channelBackup = channelopener.channelBackup(cid)
            }
            // TODO: handle incomplete TX
            root.close()
        }
    }

    FontMetrics {
        id: amountFontMetrics
        font: amountBtc.font
    }
}
