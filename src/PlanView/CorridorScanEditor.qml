import QtQuick          2.3
import QtQuick.Controls 1.2
import QtQuick.Controls.Styles 1.4
import QtQuick.Dialogs  1.2
import QtQuick.Extras   1.4
import QtQuick.Layouts  1.2

import QGroundControl               1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Vehicle       1.0
import QGroundControl.Controls      1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Palette       1.0
import QGroundControl.FlightMap     1.0

Rectangle {
    id:         _root
    height:     visible ? (editorColumn.height + (_margin * 2)) : 0
    width:      availableWidth
    color:      qgcPal.windowShadeDark
    radius:     _radius

    // The following properties must be available up the hierarchy chain
    //property real   availableWidth    ///< Width for control
    //property var    missionItem       ///< Mission Item for editor

    property real   _margin:                    ScreenTools.defaultFontPixelWidth / 2
    property real   _fieldWidth:                ScreenTools.defaultFontPixelWidth * 10.5
    property var    _vehicle:                   QGroundControl.multiVehicleManager.activeVehicle ? QGroundControl.multiVehicleManager.activeVehicle : QGroundControl.multiVehicleManager.offlineEditingVehicle
    property real   _cameraMinTriggerInterval:  missionItem.cameraCalc.minTriggerInterval.rawValue

    function polygonCaptureStarted() {
        missionItem.clearPolygon()
    }

    function polygonCaptureFinished(coordinates) {
        for (var i=0; i<coordinates.length; i++) {
            missionItem.addPolygonCoordinate(coordinates[i])
        }
    }

    function polygonAdjustVertex(vertexIndex, vertexCoordinate) {
        missionItem.adjustPolygonCoordinate(vertexIndex, vertexCoordinate)
    }

    function polygonAdjustStarted() { }
    function polygonAdjustFinished() { }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    Column {
        id:                 editorColumn
        anchors.margins:    _margin
        anchors.top:        parent.top
        anchors.left:       parent.left
        anchors.right:      parent.right

        ColumnLayout {
            id:             wizardModeColumn
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        _margin
            visible:        !missionItem.corridorPolyline.isValid || missionItem.wizardMode

            QGCLabel {
                Layout.fillWidth:   true
                wrapMode:           Text.WordWrap
                text:               qsTr("Use as ferramentas de formatos para criar uma rota sobre a área de interesse.")
            }

            /*
              Trial of new "done" model so leaving for now in case it comes back
            QGCButton {
                text:               qsTr("Done With Polyline")
                Layout.fillWidth:   true
                enabled:            missionItem.corridorPolyline.isValid && !missionItem.corridorPolyline.traceMode
                onClicked: {
                    missionItem.wizardMode = false
                    // Trial of no auto select next item
                    //editorRoot.selectNextNotReadyItem()
                }
            }
            */
        }

        Column {
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        _margin
            visible:        !wizardModeColumn.visible

            QGCTabBar {
                id:             tabBar
                anchors.left:   parent.left
                anchors.right:  parent.right

                Component.onCompleted: currentIndex = 0

                QGCTabButton { text: qsTr("Rota de vôo") }
                //QGCTabButton { text: qsTr("Camera") }
            }

            Column {
                anchors.left:       parent.left
                anchors.right:      parent.right
                spacing:            _margin
                visible:            tabBar.currentIndex == 0

                QGCLabel {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    text:           qsTr("WARNING: Photo interval is below minimum interval (%1 secs) supported by camera.").arg(_cameraMinTriggerInterval.toFixed(1))
                    wrapMode:       Text.WordWrap
                    color:          qgcPal.warningText
                    visible:        missionItem.cameraShots > 0 && _cameraMinTriggerInterval !== 0 && _cameraMinTriggerInterval > missionItem.timeBetweenShots
                }


                CameraCalcGrid {
                    cameraCalc:                     missionItem.cameraCalc
                    vehicleFlightIsFrontal:         true
                    distanceToSurfaceLabel:         qsTr("Altitude")
                    distanceToSurfaceAltitudeMode:  missionItem.followTerrain ?
                                                        QGroundControl.AltitudeModeAboveTerrain :
                                                        (missionItem.cameraCalc.distanceToSurfaceRelative ? QGroundControl.AltitudeModeRelative : QGroundControl.AltitudeModeAbsolute)
                    frontalDistanceLabel:           qsTr("Trigger Dist")
                    sideDistanceLabel:              qsTr("Espaçamento")
                }

                SectionHeader {
                    id:             corridorHeader
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    text:           qsTr("Corredor")
                }

                GridLayout {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    columnSpacing:  _margin
                    rowSpacing:     _margin
                    columns:        2
                    visible:        corridorHeader.checked

                    QGCLabel { text: qsTr("Largura") }
                    FactTextField {
                        fact:                   missionItem.corridorWidth
                        Layout.fillWidth:       true
                    }

                    QGCLabel { text: qsTr("Curva") }
                    FactTextField {
                        fact:                   missionItem.turnAroundDistance
                        Layout.fillWidth:       true
                    }

                    QGCOptionsComboBox {
                        Layout.columnSpan:  2
                        Layout.fillWidth:   true
                        visible:            false

                        model: [
                            {
                                text:       qsTr("Images in turnarounds"),
                                fact:       missionItem.cameraTriggerInTurnAround,
                                enabled:    missionItem.hoverAndCaptureAllowed ? !missionItem.hoverAndCapture.rawValue : true,
                                visible:    true
                            },
                            {
                                text:       qsTr("Relative altitude"),
                                enabled:    missionItem.cameraCalc.isManualCamera && !missionItem.followTerrain,
                                visible:    QGroundControl.corePlugin.options.showMissionAbsoluteAltitude || (!missionItem.cameraCalc.distanceToSurfaceRelative && !missionItem.followTerrain),
                                checked:    missionItem.cameraCalc.distanceToSurfaceRelative
                            }
                        ]

                        onItemClicked: {
                            if (index == 1) {
                                missionItem.cameraCalc.distanceToSurfaceRelative = !missionItem.cameraCalc.distanceToSurfaceRelative
                                console.log(missionItem.cameraCalc.distanceToSurfaceRelative)
                            }
                        }
                    }
                }

                QGCButton {
                    text:       qsTr("Rotacionar ponto de entrada")
                    onClicked:  missionItem.rotateEntryPoint()
                }

                SectionHeader {
                    id:             terrainHeader
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    text:           qsTr("Terreno")
                    checked:        missionItem.followTerrain
                }

                ColumnLayout {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    spacing:        _margin
                    visible:        terrainHeader.checked

                    QGCCheckBox {
                        id:         followsTerrainCheckBox
                        text:       qsTr("Drone segue altitude terreno")
                        checked:    missionItem.followTerrain
                        onClicked:  missionItem.followTerrain = checked
                    }

                    GridLayout {
                        Layout.fillWidth:   true
                        columnSpacing:      _margin
                        rowSpacing:         _margin
                        columns:            2
                        visible:            followsTerrainCheckBox.checked

                        QGCLabel { text: qsTr("Tolerance") }
                        FactTextField {
                            fact:               missionItem.terrainAdjustTolerance
                            Layout.fillWidth:   true
                        }

                        QGCLabel { text: qsTr("Max Climb Rate") }
                        FactTextField {
                            fact:               missionItem.terrainAdjustMaxClimbRate
                            Layout.fillWidth:   true
                        }

                        QGCLabel { text: qsTr("Max Descent Rate") }
                        FactTextField {
                            fact:               missionItem.terrainAdjustMaxDescentRate
                            Layout.fillWidth:   true
                        }
                    }
                }

                SectionHeader {
                    id:             statsHeader
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    text:           qsTr("Statistics")
                    visible:        false
                }

                //TransectStyleComplexItemStats { }
            } // Grid Column

            Column {
                anchors.left:       parent.left
                anchors.right:      parent.right
                spacing:            _margin
                //visible:            tabBar.currentIndex == 1
                visible:            false

                CameraCalcCamera {
                    cameraCalc: missionItem.cameraCalc
                }
            }
        }
    }
}
