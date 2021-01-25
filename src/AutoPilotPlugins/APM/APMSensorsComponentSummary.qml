import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Controls.Styles  1.4

import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controllers   1.0
import QGroundControl.ArduPilot     1.0

/*
    IMPORTANT NOTE: Any changes made here must also be made to SensorsComponentSummary.qml
*/

Item {
    anchors.fill:   parent

    APMSensorsComponentController { id: controller; }

    APMSensorParams {
        id:                     sensorParams
        factPanelController:    controller
    }

    Column {
        anchors.fill:       parent

        Repeater {
            model: 3

            VehicleSummaryRow {
                labelText:  qsTr("Bússola ") + (index + 1) + ""
                valueText:  sensorParams.rgCompassAvailable[index] ?
                                (sensorParams.rgCompassCalibrated[index] ?
                                     (sensorParams.rgCompassPrimary[index] ? "Primária" : "Secundária") +
                                     (sensorParams.rgCompassExternalParamAvailable[index] ?
                                          (sensorParams.rgCompassExternal[index] ? ", Externa" : ", Interna" ) :
                                          "") :
                                     qsTr("Calibração necessária")) :
                                qsTr("Não instalada")
            }
        }

        VehicleSummaryRow {
            labelText: qsTr("Accelerômetros")
            valueText: controller.accelSetupNeeded ? qsTr("Calibração necessária") : qsTr("Pronto")
        }
    }
}
