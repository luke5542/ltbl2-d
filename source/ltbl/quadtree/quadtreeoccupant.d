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

    void quadtreeUpdate() {
        if (_quadtreeNode !is null)
            _quadtreeNode.update(this);
    }

    void quadtreeRemove() {
        if (_quadtreeNode !is null)
            _quadtreeNode.remove(this);
    }

    abstract FloatRect getAABB();
}
