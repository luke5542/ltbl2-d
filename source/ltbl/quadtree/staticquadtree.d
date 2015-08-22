module ltbl.quadtree.staticquadtree;

import ltbl.quadtree.quadtree;
import ltbl.quadtree.quadtreeoccupant;

import dsfml.graphics;

class StaticQuadtree : Quadtree
{
    this()
    {
        super();
    }

    this(ref const(FloatRect) rootRegion)
    {
        _rootNode.reset(new QuadtreeNode(rootRegion, 0, null, this));
    }

    void create(ref const(FloatRect) rootRegion)
    {
        _rootNode.reset(new QuadtreeNode(rootRegion, 0, null, this));
    }

    // Inherited from Quadtree
    void add(QuadtreeOccupant oc)
    {
        assert(created());

        setQuadtree(oc);

        // If the occupant fits in the root node
        if (rectContains(_rootNode.getRegion(), oc.getAABB()))
            _rootNode.add(oc);
        else
            _outsideRoot.insert(oc);
    }

    void clear()
    {
        _rootNode.reset();
    }

    @property const(FloatRect) rootRegion() const
    {
        return _rootNode.getRegion();
    }

    @property bool created() const
    {
        return _rootNode !is null;
    }
}
