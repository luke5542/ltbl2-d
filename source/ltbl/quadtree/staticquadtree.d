module ltbl.quadtree.staticquadtree;

import ltbl.quadtree.quadtree;

class StaticQuadtree : Quadtree
{
    StaticQuadtree() {}

    StaticQuadtree(const ref FloatRect rootRegion) {
        _rootNode.reset(new QuadtreeNode(rootRegion, 0, null, this));
    }

    void create(const ref FloatRect rootRegion) {
        _rootNode.reset(new QuadtreeNode(rootRegion, 0, null, this));
    }

    // Inherited from Quadtree
    void add(QuadtreeOccupant oc) {
        assert(created());

        setQuadtree(oc);

        // If the occupant fits in the root node
        if (rectContains(_rootNode.getRegion(), oc.getAABB()))
            _rootNode.add(oc);
        else
            _outsideRoot.insert(oc);
    }

    void clear() {
        _rootNode.reset();
    }

    const FloatRect getRootRegion() {
        return _rootNode.getRegion();
    }

    bool created() const {
        return _rootNode !is null;
    }
}
