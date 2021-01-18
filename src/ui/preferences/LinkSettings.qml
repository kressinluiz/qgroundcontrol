/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


import QtQuick          2.3
import QtQuick.Controls 1.2
import QtQuick.Dialogs  1.2

import QGroundControl                       1.0
import QGroundControl.Controls              1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.Palette               1.0

Rectangle {
    id:                 _linkRoot
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    property var _currentSelection: null
    property int _firstColumn:      ScreenTools.defaultFontPixelWidth * 12
    property int _secondColumn:     ScreenTools.defaultFontPixelWidth * 30

    QGCPalette {
        id:                 qgcPal
        colorGroupEnabled:  enabled
    }

    function openCommSettings(lconf) {
        settingLoader.linkConfig = lconf
        settingLoader.sourceComponent = commSettings
        settingLoader.visible = true
    }

    function closeCommSettings() {
        settingLoader.visible = false
        settingLoader.sourceComponent = null
    }

    QGCFlickable {
        clip:               true
        anchors.top:        parent.top
        width:              parent.width
        height:             parent.height - buttonRow.height
        contentHeight:      settingsColumn.height
        contentWidth:       _linkRoot.width
        flickableDirection: Flickable.VerticalFlick

        Column {
            id:                 settingsColumn
            width:              _linkRoot.width
            anchors.margins:    ScreenTools.defaultFontPixelWidth
            spacing:            ScreenTools.defaultFontPixelHeight / 2
            Repeater {
                model: QGroundControl.linkManager.linkConfigurations
                delegate: QGCButton {
                    anchors.horizontalCenter:   settingsColumn.horizontalCenter
                    width:                      _linkRoot.width * 0.5
                    text:                       object.name
                    autoExclusive:              true
                    visible:                    !object.dynamic
                    onClicked: {
                        checked = true
                        _currentSelection = object
                        connectButton.enabled = _currentSelection && !_currentSelection.link
                        disconnectButton.enabled = _currentSelection && _currentSelection.link
                    }
                }
            }
        }
    }

    Row {
        id:                 buttonRow
        spacing:            ScreenTools.defaultFontPixelWidth
        anchors.bottom:     parent.bottom
        anchors.margins:    ScreenTools.defaultFontPixelWidth
        anchors.horizontalCenter: parent.horizontalCenter
        QGCButton {
            width:      ScreenTools.defaultFontPixelWidth * 10
            text:       qsTr("Apagar")
            enabled:    _currentSelection && !_currentSelection.dynamic
            onClicked: {
                if(_currentSelection)
                    deleteDialog.visible = true
            }
            MessageDialog {
                id:         deleteDialog
                visible:    false
                icon:       StandardIcon.Warning
                standardButtons: StandardButton.Yes | StandardButton.No
                title:      qsTr("Remover Controle Remoto")
                text:       _currentSelection ? qsTr("Remover %1. Isso é mesmo o que você quer?").arg(_currentSelection.name) : ""
                onYes: {
                    if(_currentSelection)
                        QGroundControl.linkManager.removeConfiguration(_currentSelection)
                    addLinkConfigButton.enabled = !QGroundControl.linkManager.isThereMoreThanOneLinkConfiguration()
                    connectButton.enabled = _currentSelection && !_currentSelection.link
                    disconnectButton.enabled = _currentSelection && _currentSelection.link
                    deleteDialog.visible = false
                }
                onNo: {
                    deleteDialog.visible = false
                }
            }
        }
        QGCButton {
            text:       qsTr("Editar")
            enabled:    _currentSelection && !_currentSelection.link
            visible:    false
            onClicked: {
                _linkRoot.openCommSettings(_currentSelection)
            }
        }
        QGCButton {
            id:         addLinkConfigButton
            text:       qsTr("Adicionar")
            enabled:    !QGroundControl.linkManager.isThereMoreThanOneLinkConfiguration()
            onClicked: {
                _linkRoot.openCommSettings(null)
            }
        }
        QGCButton {
            id:         connectButton
            text:       qsTr("Conectar")
            enabled:    _currentSelection && !_currentSelection.link
            onClicked:  {
                            QGroundControl.linkManager.createConnectedLink(_currentSelection)
                            connectButton.enabled = _currentSelection && !_currentSelection.link
                            disconnectButton.enabled = _currentSelection && _currentSelection.link
                        }
        }
        QGCButton {
            id:         disconnectButton
            text:       qsTr("Desconectar")
            enabled:    _currentSelection && _currentSelection.link
            onClicked:  {
                            _currentSelection.link.disconnect()
                            connectButton.enabled = _currentSelection && !_currentSelection.link
                            disconnectButton.enabled = _currentSelection && _currentSelection.link
                        }
        }
        QGCButton {
            text:       qsTr("MockLink Options")
            visible:    _currentSelection && _currentSelection.link && _currentSelection.link.isMockLink
            onClicked:  mainWindow.showPopupDialogFromSource("qrc:/unittest/MockLinkOptionsDlg.qml", { link: _currentSelection.link })
        }
    }

    Loader {
        id:             settingLoader
        anchors.fill:   parent
        visible:        false
        property var linkConfig: null
        property var editConfig: null
    }

    //---------------------------------------------
    // Comm Settings
    Component {
        id: commSettings
        Rectangle {
            id:             settingsRect
            color:          qgcPal.window
            anchors.fill:   parent
            property real   _panelWidth:    width * 0.8
            Component.onCompleted: {
                // If editing, create copy for editing
                if(linkConfig) {
                    editConfig = QGroundControl.linkManager.startConfigurationEditing(linkConfig)
                } else {
                    // Create new link configuration
                    editConfig = QGroundControl.linkManager.createConfiguration(LinkConfiguration.TypeBluetooth, "Controle VigiAir")
//                    if(ScreenTools.isSerialAvailable) {
//                        editConfig = QGroundControl.linkManager.createConfiguration(LinkConfiguration.TypeSerial, "Unnamed")
//                    } else {
//                        editConfig = QGroundControl.linkManager.createConfiguration(LinkConfiguration.TypeUdp,    "Unnamed")
//                    }
                }
            }
            Component.onDestruction: {
                if(editConfig) {
                    QGroundControl.linkManager.cancelConfigurationEditing(editConfig)
                    editConfig = null
                }
            }
            Column {
                id:                 settingsTitle
                spacing:            ScreenTools.defaultFontPixelHeight * 0.5
                QGCLabel {
                    text:   linkConfig ? qsTr("Alterar Controle Remoto") : qsTr("Adicionar Controle Remoto")
                    font.pointSize: ScreenTools.mediumFontPointSize
                }
                Rectangle {
                    height: 1
                    width:  settingsRect.width
                    color:  qgcPal.button
                }
            }
            QGCFlickable {
                id:                 settingsFlick
                clip:               true
                anchors.top:        settingsTitle.bottom
                anchors.bottom:     commButtonRow.top
                width:              parent.width
                anchors.margins:    ScreenTools.defaultFontPixelWidth
                contentHeight:      commSettingsColumn.height
                contentWidth:       _linkRoot.width
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior:     Flickable.StopAtBounds
                Column {
                    id:                 commSettingsColumn
                    width:              _linkRoot.width
                    anchors.margins:    ScreenTools.defaultFontPixelWidth
                    spacing:            ScreenTools.defaultFontPixelHeight * 0.5
                    //-----------------------------------------------------------------
                    //-- General
                    Item {
                        width:                      _panelWidth
                        height:                     generalLabel.height
                        anchors.margins:            ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter:   parent.horizontalCenter
                        visible: false
                        QGCLabel {
                            id:                     generalLabel
                            text:                   qsTr("General")
                            font.family:            ScreenTools.demiboldFontFamily
                        }
                    }
                    Rectangle {
                        height:                     generalCol.height + (ScreenTools.defaultFontPixelHeight * 2)
                        width:                      _panelWidth
                        color:                      qgcPal.windowShade
                        anchors.margins:            ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter:   parent.horizontalCenter
                        visible: false
                        Column {
                            id:                     generalCol
                            anchors.centerIn:       parent
                            anchors.margins:        ScreenTools.defaultFontPixelWidth
                            spacing:                ScreenTools.defaultFontPixelHeight * 0.5
                            Row {
                                spacing:    ScreenTools.defaultFontPixelWidth
                                QGCLabel {
                                    text:   qsTr("Name:")
                                    width:  _firstColumn
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                QGCTextField {
                                    id:     nameField
                                    text:   editConfig ? editConfig.name : ""
                                    width:  _secondColumn
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Row {
                                spacing:            ScreenTools.defaultFontPixelWidth
                                QGCLabel {
                                    text:           qsTr("Type:")
                                    width:          _firstColumn
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                //-----------------------------------------------------
                                // When editing, you can't change the link type
                                QGCLabel {
                                    text:           linkConfig ? QGroundControl.linkManager.linkTypeStrings[linkConfig.linkType] : ""
                                    visible:        linkConfig != null
                                    width:          _secondColumn
                                    anchors.verticalCenter: parent.verticalCenter
                                    Component.onCompleted: {
                                        if(linkConfig != null) {
                                            linkSettingLoader.source  = linkConfig.settingsURL
                                            linkSettingLoader.visible = true
                                        }
                                    }
                                }
                                //-----------------------------------------------------
                                // When creating, select a link type
                                QGCComboBox {
                                    id:             linkTypeCombo
                                    width:          _secondColumn
                                    visible:        linkConfig == null
                                    model:          QGroundControl.linkManager.linkTypeStrings
                                    anchors.verticalCenter: parent.verticalCenter
                                    onActivated: {
                                        if (index != -1 && index !== editConfig.linkType) {
                                            // Destroy current panel
                                            linkSettingLoader.source = ""
                                            linkSettingLoader.visible = false
                                            // Save current name
                                            var name = nameField.text
                                            // Discard link configuration (old type)
                                            QGroundControl.linkManager.cancelConfigurationEditing(editConfig)
                                            // Create new link configuration
                                            editConfig = QGroundControl.linkManager.createConfiguration(index, name)
                                            // Load appropriate configuration panel
                                            linkSettingLoader.source  = editConfig.settingsURL
                                            linkSettingLoader.visible = true
                                        }
                                    }
                                    Component.onCompleted: {
                                        if(linkConfig == null) {
                                            linkTypeCombo.currentIndex = 0
                                            linkSettingLoader.source   = editConfig.settingsURL
                                            linkSettingLoader.visible  = true
                                        }
                                    }
                                }
                            }
                            Item {
                                height: ScreenTools.defaultFontPixelHeight * 0.5
                                width:  parent.width
                            }
                            //-- Auto Connect on Start
                            QGCCheckBox {
                                text:               qsTr("Automatically Connect on Start")
                                checked:            false
                                onCheckedChanged: {
                                    if(editConfig) {
                                        editConfig.autoConnect = checked
                                    }
                                }
                                Component.onCompleted: {
                                    if(editConfig)
                                        checked = editConfig.autoConnect
                                }
                            }
                            QGCCheckBox {
                                text:               qsTr("High Latency")
                                checked:            false
                                onCheckedChanged: {
                                    if(editConfig) {
                                        editConfig.highLatency = checked
                                    }
                                }
                                Component.onCompleted: {
                                    if(editConfig)
                                        checked = editConfig.highLatency
                                }
                            }
                        }
                    }
                    Item {
                        height: ScreenTools.defaultFontPixelHeight
                        width:  parent.width
                    }
                    //-----------------------------------------------------------------
                    //-- Link Specific Settings
                    Item {
                        width:                      _panelWidth
                        height:                     linkLabel.height
                        anchors.margins:            ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter:   parent.horizontalCenter
                        QGCLabel {
                            id:                     linkLabel
                            text:                   editConfig ? editConfig.settingsTitle : ""
                            visible:                linkSettingLoader.source != ""
                            font.family:            ScreenTools.demiboldFontFamily
                        }
                    }
                    Rectangle {
                        height:                     linkSettingLoader.height + (ScreenTools.defaultFontPixelHeight * 2)
                        width:                      _panelWidth
                        color:                      qgcPal.windowShade
                        anchors.margins:            ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter:   parent.horizontalCenter
                        Item {
                            height:                 linkSettingLoader.height
                            width:                  linkSettingLoader.width
                            anchors.centerIn:       parent
                            Loader {
                                id:                 linkSettingLoader
                                visible:            false
                                property var subEditConfig: editConfig
                            }
                        }
                    }
                }
            }
            Row {
                id:                 commButtonRow
                spacing:            ScreenTools.defaultFontPixelWidth
                anchors.margins:    ScreenTools.defaultFontPixelWidth
                anchors.bottom:     parent.bottom
                anchors.right:      parent.right
                QGCButton {
                    width:      ScreenTools.defaultFontPixelWidth * 10
                    text:       qsTr("Salvar")
                    enabled:    nameField.text !== ""
                    onClicked: {
                        // Save editting
                        linkSettingLoader.item.saveSettings()
                        editConfig.name = nameField.text
                        if(linkConfig) {
                            QGroundControl.linkManager.endConfigurationEditing(linkConfig, editConfig)
                        } else {
                            // If it was edited, it's no longer "dynamic"
                            editConfig.dynamic = false
                            QGroundControl.linkManager.endCreateConfiguration(editConfig)
                        }
                        linkSettingLoader.source = ""
                        editConfig = null
                        _linkRoot.closeCommSettings()
                         addLinkConfigButton.enabled = !QGroundControl.linkManager.isThereMoreThanOneLinkConfiguration()
                    }
                }
                QGCButton {
                    width:      ScreenTools.defaultFontPixelWidth * 10
                    text:       qsTr("Cancelar")
                    onClicked: {
                        QGroundControl.linkManager.cancelConfigurationEditing(editConfig)
                        editConfig = null
                        _linkRoot.closeCommSettings()
                    }
                }
            }
        }
    }
}
