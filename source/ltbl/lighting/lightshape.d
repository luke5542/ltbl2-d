module ltbl.lighting.lightshape;

import ltbl;

import dsfml.graphics;

class LightShape : QuadtreeOccupant {

    public
    {
        bool renderLightOverShape;
        ConvexShape shape;
    }

    this()
    {
        renderLightOverShape = true;
    }

    override FloatRect getAABB() {
        return shape.getGlobalBounds();
    }
}
