module ltbl.quadtree.dynamicquadtree;

import ltbl;

import dsfml.graphics;

class DynamicQuadtree : Quadtree {

    public
    {
        long minOutsideRoot;
        long maxOutsideRoot;
    }

    this()
    {
        minOutsideRoot = 1;
        maxOutsideRoot = 8;
    }

    this(ref const(FloatRect) rootRegion)
    {
        this();
        create(rootRegion);
    }

    void create(ref const(FloatRect) rootRegion) {
        _rootNode = new QuadtreeNode(rootRegion, 0, null, this);
    }

    // Inherited from Quadtree
    override void add(QuadtreeOccupant oc) {
        assert(created());

        // If the occupant fits in the root node
        if (rectContains(_rootNode.region, oc.getAABB()))
            _rootNode.add(oc);
        else
            _outsideRoot ~= oc;

        setQuadtree(oc);
    }

    void clear()
    {
        _rootNode = null;
    }

    @property bool created() const
    {
        return _rootNode !is null;
    }

    @property const(FloatRect) rootRegion() const
    {
        assert(created());
        return _rootNode.region;
    }

    // Resizes Quadtree
    void trim()
    {
        if(_rootNode is null)
            return;

        // Check if should grow
        if(_outsideRoot.length > maxOutsideRoot)
            expand();
        else if(_outsideRoot.length < minOutsideRoot && _rootNode._hasChildren)
            contract();
    }

private:

    void expand() {
        // Find direction with most occupants
        Vector2f averageDir = Vector2f(0.0, 0.0);

        foreach(occupant; _outsideRoot)
            averageDir += vectorNormalize(rectCenter(occupant.getAABB()) - rectCenter(_rootNode.region));

        Vector2f centerOffsetDist = Vector2f(rectHalfDims(_rootNode.region) / oversizeMultiplier);

        Vector2f centerOffset = Vector2f((averageDir.x > 0.0 ? 1.0 : -1.0) * centerOffsetDist.x,
                                (averageDir.y > 0.0 ? 1.0 : -1.0) * centerOffsetDist.y);

        // Child node position of current root node
        int rX = centerOffset.x > 0.0 ? 0 : 1;
        int rY = centerOffset.y > 0.0 ? 0 : 1;

        FloatRect newRootAABB = rectFromBounds(Vector2f(0.0, 0.0), centerOffsetDist * 4.0);

        newRootAABB = rectRecenter(newRootAABB, centerOffset + rectCenter(_rootNode.region));

        QuadtreeNode newRoot = new QuadtreeNode(newRootAABB,  _rootNode._level + 1, null, this);

        // ----------------------- Manual Children Creation for New Root -------------------------

        Vector2f halfRegionDims = rectHalfDims(newRoot.region);
        Vector2f regionLowerBound = rectLowerBound(newRoot.region);
        Vector2f regionCenter = rectCenter(newRoot.region);

        // Create the children nodes
        for(int x = 0; x < 2; x++) {
            for(int y = 0; y < 2; y++) {
                if(x == rX && y == rY) {
                    newRoot._children[x + y * 2] = _rootNode;
                } else {
                    Vector2f offset = Vector2f(x * halfRegionDims.x, y * halfRegionDims.y);

                    FloatRect childAABB = rectFromBounds(regionLowerBound + offset, regionCenter + offset);

                    // Scale up AABB by the oversize multiplier
                    Vector2f center = rectCenter(childAABB);

                    childAABB.width *= oversizeMultiplier;
                    childAABB.height *= oversizeMultiplier;

                    childAABB = rectRecenter(childAABB, center);

                    newRoot._children[x + y * 2] = new QuadtreeNode(childAABB, _rootNode._level, newRoot, this);
                }
            }
        }

        newRoot._hasChildren = true;
        newRoot._numOccupantsBelow = _rootNode._numOccupantsBelow;
        _rootNode._parent = newRoot;

        // Transfer ownership
        _rootNode = newRoot;

        // ----------------------- Try to Add Previously Outside Root -------------------------

        // Make copy so don't try to re-add ones just added
        QuadtreeOccupant[] outsideRootCopy = _outsideRoot.dup;
        _outsideRoot.length = 0;

        foreach(occupant; outsideRootCopy)
            add(occupant);
    }

    void contract() {
        assert(_rootNode._hasChildren);

        // Find child with the most occupants and shrink to that
        int maxIndex = 0;

        for (int i = 1; i < 4; i++) {
            if (_rootNode._children[i].numOccupantsBelow() >
                _rootNode._children[maxIndex].numOccupantsBelow())
                maxIndex = i;
        }

        // Reorganize
        for (int i = 0; i < 4; i++) {
            if (i == maxIndex)
                continue;

            _rootNode._children[i].removeForDeletion(_outsideRoot);
        }

        QuadtreeNode newRoot = _rootNode._children[maxIndex];
        _rootNode._children[maxIndex] = null;

        _rootNode.destroyChildren();

        _rootNode.removeForDeletion(_outsideRoot);

        _rootNode = newRoot;

        _rootNode._parent = null;
    }
}
