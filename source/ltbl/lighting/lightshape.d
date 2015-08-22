module ltbl.lighting.lightshape;

import ltbl.quadtree.quadtreeoccupant;

import dsfml.graphics;

class LightShape : QuadtreeOccupant {

    public
    {
        bool renderLightOverShape;
        ConvexShape shape;
    }

    this()
    {
        _renderLightOverShape = true;
    }

    override FloatRect getAABB() const {
        return _shape.getGlobalBounds();
    }
}
