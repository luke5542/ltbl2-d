module ltbl.quadtree.quadtreeoccupant;

import ltbl.quadtree.quadtree;
import ltbl.quadtree.quadtreenode;

class QuadtreeOccupant
{
    package
    {
        QuadtreeNode _quadtreeNode;
        Quadtree _quadtree;
    }

    QuadtreeOccupant(){}

    void quadtreeUpdate() {
        if (_quadtreeNode != nullptr)
            _quadtreeNode.update(this);
    }

    void quadtreeRemove() {
        if (_quadtreeNode != nullptr)
            _quadtreeNode.remove(this);
    }

    abstract FloatRect getAABB();
}
