module ltbl.quadtree.staticquadtree;

import ltbl;

import dsfml.graphics;

class StaticQuadtree : Quadtree
{
    this()
    {
        super();
    }

    this(ref const(FloatRect) rootRegion)
    {
        _rootNode = new QuadtreeNode(rootRegion, 0, null, this);
    }

    void create(ref const(FloatRect) rootRegion)
    {
        _rootNode = new QuadtreeNode(rootRegion, 0, null, this);
    }

    // Inherited from Quadtree
    override void add(QuadtreeOccupant oc)
    {
        assert(created());

        setQuadtree(oc);

        // If the occupant fits in the root node
        if (rectContains(_rootNode.region(), oc.getAABB()))
            _rootNode.add(oc);
        else
            _outsideRoot ~= oc;
    }

    void clear()
    {
        _rootNode = null;
    }

    @property const(FloatRect) rootRegion() const
    {
        return _rootNode.region();
    }

    @property bool created() const
    {
        return _rootNode !is null;
    }
}
