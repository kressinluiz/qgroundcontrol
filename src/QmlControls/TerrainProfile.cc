/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "TerrainProfile.h"
#include "MissionController.h"
#include "QmlObjectListModel.h"
#include "FlightPathSegment.h"
#include "SimpleMissionItem.h"
#include "ComplexMissionItem.h"

#include <QSGSimpleRectNode>

TerrainProfile::TerrainProfile(QQuickItem* parent)
    : QQuickItem(parent)
{
    setFlag(QQuickItem::ItemHasContents, true);

    connect(this, &QQuickItem::heightChanged,           this, &QQuickItem::update);
    connect(this, &TerrainProfile::visibleWidthChanged, this, &QQuickItem::update);

    // This collapse multiple _updateSignals in a row to a single update
    connect(this, &TerrainProfile::_updateSignal, this, &QQuickItem::update, Qt::QueuedConnection);
    qgcApp()->addCompressedSignal(QMetaMethod::fromSignal(&TerrainProfile::_updateSignal));
}

void TerrainProfile::componentComplete(void)
{
    QQuickItem::componentComplete();
}

void TerrainProfile::setMissionController(MissionController* missionController)
{
    if (missionController != _missionController) {
        _missionController =    missionController;
        _visualItems =          _missionController->visualItems();

        emit missionControllerChanged();

        connect(_missionController, &MissionController::visualItemsChanged,         this, &TerrainProfile::_newVisualItems);
        connect(_missionController, &MissionController::minAMSLAltitudeChanged,     this, &TerrainProfile::minAMSLAltChanged);

        connect(this,               &TerrainProfile::horizontalMarginChanged,       this, &TerrainProfile::_updateSignal, Qt::QueuedConnection);
        connect(this,               &TerrainProfile::visibleWidthChanged,           this, &TerrainProfile::_updateSignal, Qt::QueuedConnection);
        connect(_missionController, &MissionController::recalcTerrainProfile,       this, &TerrainProfile::_updateSignal, Qt::QueuedConnection);
    }
}

void TerrainProfile::_newVisualItems(void)
{
    _visualItems = _missionController->visualItems();
    emit _updateSignal();
}

void TerrainProfile::_createGeometry(QSGGeometryNode*& geometryNode, QSGGeometry*& geometry, QSGGeometry::DrawingMode drawingMode, const QColor& color)
{
    QSGFlatColorMaterial* terrainMaterial = new QSGFlatColorMaterial;
    terrainMaterial->setColor(color);

    geometry = new QSGGeometry(QSGGeometry::defaultAttributes_Point2D(), 0);
    geometry->setDrawingMode(drawingMode);
    geometry->setLineWidth(2);

    geometryNode = new QSGGeometryNode;
    geometryNode->setFlag(QSGNode::OwnsGeometry);
    geometryNode->setFlag(QSGNode::OwnsMaterial);
    geometryNode->setFlag(QSGNode::OwnedByParent);
    geometryNode->setMaterial(terrainMaterial);
    geometryNode->setGeometry(geometry);
}

void TerrainProfile::_updateSegmentCounts(FlightPathSegment* segment, int& cFlightProfileSegments, int& cTerrainProfilePoints, int& cMissingTerrainSegments, int& cTerrainCollisionSegments, double& maxTerrainHeight)
{
    if (_shouldAddFlightProfileSegment(segment)) {
        cFlightProfileSegments++;
    }

    if (_shouldAddMissingTerrainSegment(segment)) {
        cMissingTerrainSegments += 1;
    } else {
        cTerrainProfilePoints += segment->amslTerrainHeights().count();
        for (int i=0; i<segment->amslTerrainHeights().count(); i++) {
            maxTerrainHeight = qMax(maxTerrainHeight, segment->amslTerrainHeights()[i].value<double>());
        }
    }
    if (segment->terrainCollision()) {
        cTerrainCollisionSegments++;
    }
}

void TerrainProfile::_addTerrainProfileSegment(FlightPathSegment* segment, double currentDistance, double amslAltRange, QSGGeometry::Point2D* terrainVertices, int& terrainProfileVertexIndex)
{
    double terrainDistance = 0;
    for (int heightIndex=0; heightIndex<segment->amslTerrainHeights().count(); heightIndex++) {
        // Move along the x axis which is distance
        if (heightIndex == 0) {
            // The first point in the segment is at the position of the last point. So nothing to do here.
        } else if (heightIndex == segment->amslTerrainHeights().count() - 2) {
            // The distance between the last two heights differs with each terrain query
            terrainDistance += segment->finalDistanceBetween();
        } else {
            // The distance between all terrain heights except for the last is the same
            terrainDistance += segment->distanceBetween();
        }

        // Move along the y axis which is a view or terrain height as a percentage between the min/max AMSL altitude for all segments
        double amslTerrainHeight = segment->amslTerrainHeights()[heightIndex].value<double>();
        double terrainHeightPercent = qMax(((amslTerrainHeight - _missionController->minAMSLAltitude()) / amslAltRange), 0.0);

        float x = (currentDistance + terrainDistance) * _pixelsPerMeter;
        float y = _availableHeight() - (terrainHeightPercent * _availableHeight());
        _setVertex(terrainVertices[terrainProfileVertexIndex++], x, y);
    }
}

void TerrainProfile::_addMissingTerrainSegment(FlightPathSegment* segment, double currentDistance, QSGGeometry::Point2D* missingTerrainVertices, int& missingterrainProfileVertexIndex)
{
    if (_shouldAddMissingTerrainSegment(segment)) {
        float x = currentDistance * _pixelsPerMeter;
        float y = _availableHeight();
        _setVertex(missingTerrainVertices[missingterrainProfileVertexIndex++], x, y);
        _setVertex(missingTerrainVertices[missingterrainProfileVertexIndex++], x + (segment->totalDistance() * _pixelsPerMeter), y);
    }
}

void TerrainProfile::_addTerrainCollisionSegment(FlightPathSegment* segment, double currentDistance, double amslAltRange, QSGGeometry::Point2D* terrainCollisionVertices, int& terrainCollisionVertexIndex)
{
    if (segment->terrainCollision()) {
        double amslCoord1Height =       segment->coord1AMSLAlt();
        double amslCoord2Height =       segment->coord2AMSLAlt();
        double coord1HeightPercent =    qMax(((amslCoord1Height - _missionController->minAMSLAltitude()) / amslAltRange), 0.0);
        double coord2HeightPercent =    qMax(((amslCoord2Height - _missionController->minAMSLAltitude()) / amslAltRange), 0.0);

        float x = currentDistance * _pixelsPerMeter;
        float y = _availableHeight() - (coord1HeightPercent * _availableHeight());

        _setVertex(terrainCollisionVertices[terrainCollisionVertexIndex++], x, y);

        x += segment->totalDistance() * _pixelsPerMeter;
        y = _availableHeight() - (coord2HeightPercent * _availableHeight());

        _setVertex(terrainCollisionVertices[terrainCollisionVertexIndex++], x, y);
    }
}

void TerrainProfile::_addFlightProfileSegment(FlightPathSegment* segment, double currentDistance, double amslAltRange, QSGGeometry::Point2D* flightProfileVertices, int& flightProfileVertexIndex)
{
    if (!_shouldAddFlightProfileSegment(segment)) {
        return;
    }

    double amslCoord1Height =       segment->coord1AMSLAlt();
    double amslCoord2Height =       segment->coord2AMSLAlt();
    double coord1HeightPercent =    qMax(((amslCoord1Height - _missionController->minAMSLAltitude()) / amslAltRange), 0.0);
    double coord2HeightPercent =    qMax(((amslCoord2Height - _missionController->minAMSLAltitude()) / amslAltRange), 0.0);

    float x = currentDistance * _pixelsPerMeter;
    float y = _availableHeight() - (coord1HeightPercent * _availableHeight());

    _setVertex(flightProfileVertices[flightProfileVertexIndex++], x, y);

    x += segment->totalDistance() * _pixelsPerMeter;
    y = _availableHeight() - (coord2HeightPercent * _availableHeight());

    _setVertex(flightProfileVertices[flightProfileVertexIndex++], x, y);
}

QSGNode* TerrainProfile::updatePaintNode(QSGNode* oldNode, QQuickItem::UpdatePaintNodeData* /*updatePaintNodeData*/)
{
    QSGNode*        rootNode =                  static_cast<QSGNode *>(oldNode);
    QSGGeometry*    terrainProfileGeometry =    nullptr;
    QSGGeometry*    missingTerrainGeometry =    nullptr;
    QSGGeometry*    flightProfileGeometry =     nullptr;
    QSGGeometry*    terrainCollisionGeometry =  nullptr;
    int             cTerrainProfilePoints =     0;
    int             cMissingTerrainSegments =   0;
    int             cFlightProfileSegments =    0;
    int             cTerrainCollisionSegments = 0;
    double          maxTerrainHeight =          0;

    // First we need to determine:
    //  - how many terrain profile vertices we need
    //  - how many missing terrain segments there are
    //  - how many flight profile segments we need
    //  - how many terrain collision segments there are
    //  - what is the total distance so we can calculate pixels per meter

    for (int viIndex=0; viIndex<_visualItems->count(); viIndex++) {
        VisualMissionItem*  visualItem =    _visualItems->value<VisualMissionItem*>(viIndex);
        ComplexMissionItem* complexItem =   _visualItems->value<ComplexMissionItem*>(viIndex);

        if (visualItem->simpleFlightPathSegment()) {
            FlightPathSegment* segment = visualItem->simpleFlightPathSegment();
            _updateSegmentCounts(segment, cFlightProfileSegments, cTerrainProfilePoints, cMissingTerrainSegments, cTerrainCollisionSegments, maxTerrainHeight);
        }

        if (complexItem) {
            for (int segmentIndex=0; segmentIndex<complexItem->flightPathSegments()->count(); segmentIndex++) {
                FlightPathSegment* segment = complexItem->flightPathSegments()->value<FlightPathSegment*>(segmentIndex);
                _updateSegmentCounts(segment, cFlightProfileSegments, cTerrainProfilePoints, cMissingTerrainSegments, cTerrainCollisionSegments, maxTerrainHeight);
            }
        }
    }

    double amslAltRange = qMax(_missionController->maxAMSLAltitude(), maxTerrainHeight) - _missionController->minAMSLAltitude();

#if 0
    static int counter = 0;
    qDebug() << "updatePaintNode" << counter++ << cFlightProfileSegments << cTerrainProfilePoints << cMissingTerrainSegments << cTerrainCollisionSegments;
#endif

    _pixelsPerMeter = (_visibleWidth - (_horizontalMargin * 2)) / _missionController->missionDistance();

    // Instantiate nodes
    if (!rootNode) {
        rootNode = new QSGNode;

        QSGGeometryNode* terrainProfileNode =   nullptr;
        QSGGeometryNode* missingTerrainNode =   nullptr;
        QSGGeometryNode* flightProfileNode =    nullptr;
        QSGGeometryNode* terrainCollisionNode = nullptr;

        _createGeometry(terrainProfileNode,     terrainProfileGeometry,     QSGGeometry::DrawLineStrip, "green");
        _createGeometry(missingTerrainNode,     missingTerrainGeometry,     QSGGeometry::DrawLines,     "yellow");
        _createGeometry(flightProfileNode,      flightProfileGeometry,      QSGGeometry::DrawLines,     "orange");
        _createGeometry(terrainCollisionNode,   terrainCollisionGeometry,   QSGGeometry::DrawLines,     "red");

        rootNode->appendChildNode(terrainProfileNode);
        rootNode->appendChildNode(missingTerrainNode);
        rootNode->appendChildNode(flightProfileNode);
        rootNode->appendChildNode(terrainCollisionNode);
    }

    // Allocate space for the vertices

    QSGNode* node = rootNode->childAtIndex(0);
    terrainProfileGeometry = static_cast<QSGGeometryNode*>(node)->geometry();
    terrainProfileGeometry->allocate(cTerrainProfilePoints);
    node->markDirty(QSGNode::DirtyGeometry);

    node = rootNode->childAtIndex(1);
    missingTerrainGeometry = static_cast<QSGGeometryNode*>(node)->geometry();
    missingTerrainGeometry->allocate(cMissingTerrainSegments * 2);
    node->markDirty(QSGNode::DirtyGeometry);

    node = rootNode->childAtIndex(2);
    flightProfileGeometry = static_cast<QSGGeometryNode*>(node)->geometry();
    flightProfileGeometry->allocate(cFlightProfileSegments * 2);
    node->markDirty(QSGNode::DirtyGeometry);

    node = rootNode->childAtIndex(3);
    terrainCollisionGeometry = static_cast<QSGGeometryNode*>(node)->geometry();
    terrainCollisionGeometry->allocate(cTerrainCollisionSegments * 2);
    node->markDirty(QSGNode::DirtyGeometry);

    int                     flightProfileVertexIndex =          0;
    int                     terrainProfileVertexIndex =         0;
    int                     missingterrainProfileVertexIndex =  0;
    int                     terrainCollisionVertexIndex =       0;
    double                  currentDistance =                   0;
    QSGGeometry::Point2D*   flightProfileVertices =             flightProfileGeometry->vertexDataAsPoint2D();
    QSGGeometry::Point2D*   terrainProfileVertices =            terrainProfileGeometry->vertexDataAsPoint2D();
    QSGGeometry::Point2D*   missingTerrainVertices =            missingTerrainGeometry->vertexDataAsPoint2D();
    QSGGeometry::Point2D*   terrainCollisionVertices =          terrainCollisionGeometry->vertexDataAsPoint2D();

    // This step places the vertices for display into the nodes
    for (int viIndex=0; viIndex<_visualItems->count(); viIndex++) {
        VisualMissionItem*  visualItem =    _visualItems->value<VisualMissionItem*>(viIndex);
        ComplexMissionItem* complexItem =   _visualItems->value<ComplexMissionItem*>(viIndex);

        if (complexItem) {
            if (complexItem->flightPathSegments()->count() == 0) {
                currentDistance += complexItem->complexDistance();
            } else {
                for (int segmentIndex=0; segmentIndex<complexItem->flightPathSegments()->count(); segmentIndex++) {
                    FlightPathSegment* segment = complexItem->flightPathSegments()->value<FlightPathSegment*>(segmentIndex);

                    _addFlightProfileSegment    (segment, currentDistance, amslAltRange,    flightProfileVertices,      flightProfileVertexIndex);
                    _addTerrainProfileSegment   (segment, currentDistance, amslAltRange,    terrainProfileVertices,     terrainProfileVertexIndex);
                    _addMissingTerrainSegment   (segment, currentDistance,                  missingTerrainVertices,     missingterrainProfileVertexIndex);
                    _addTerrainCollisionSegment (segment, currentDistance, amslAltRange,    terrainCollisionVertices,   terrainCollisionVertexIndex);

                    currentDistance += segment->totalDistance();
                }
            }
        }

        if (visualItem->simpleFlightPathSegment()) {
            FlightPathSegment* segment = visualItem->simpleFlightPathSegment();

            _addFlightProfileSegment    (segment, currentDistance, amslAltRange,    flightProfileVertices,      flightProfileVertexIndex);
            _addTerrainProfileSegment   (segment, currentDistance, amslAltRange,    terrainProfileVertices,     terrainProfileVertexIndex);
            _addMissingTerrainSegment   (segment, currentDistance,                  missingTerrainVertices,     missingterrainProfileVertexIndex);
            _addTerrainCollisionSegment (segment, currentDistance, amslAltRange,    terrainCollisionVertices,   terrainCollisionVertexIndex);

            currentDistance += segment->totalDistance();
        }
    }

    setImplicitWidth(_visibleWidth/*(_totalDistance * pixelsPerMeter) + (_horizontalMargin * 2)*/);
    setWidth(implicitWidth());

    emit implicitWidthChanged();
    emit widthChanged();
    emit pixelsPerMeterChanged();

    double newMaxAMSLAlt = qMax(_missionController->maxAMSLAltitude(), maxTerrainHeight);
    if (!QGC::fuzzyCompare(newMaxAMSLAlt, _maxAMSLAlt)) {
        _maxAMSLAlt = newMaxAMSLAlt;
        emit maxAMSLAltChanged();
    }

    return rootNode;
}

double TerrainProfile::minAMSLAlt(void)
{
    return _missionController->minAMSLAltitude();
}

double TerrainProfile::_availableHeight(void) const
{
    return height() - (_verticalMargin * 2);
}

void TerrainProfile::_setVertex(QSGGeometry::Point2D& vertex, double x, double y)
{
    vertex.set(x + _horizontalMargin, y + _verticalMargin);
}

bool TerrainProfile::_shouldAddFlightProfileSegment  (FlightPathSegment* segment)
{
    return !qIsNaN(segment->coord1AMSLAlt()) && !qIsNaN(segment->coord2AMSLAlt());
}

bool TerrainProfile::_shouldAddMissingTerrainSegment (FlightPathSegment* segment)
{
    return segment->amslTerrainHeights().count() == 0;
}
