module ltbl.lighting.lightshape;

import ltbl.quadtree.quadtreeoccupant;

class LightShape : QuadtreeOccupant {

    public
    {
        bool renderLightOverShape;
        ConvexShape shape;
    }

    LightShape()
    {
        _renderLightOverShape = true;
    }

    FloatRect getAABB() {
        return _shape.getGlobalBounds();
    }
}
