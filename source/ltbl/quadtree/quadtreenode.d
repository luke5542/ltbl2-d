module ltbl.quadtree.quadtreenode;

import ltbl;

import dsfml.graphics;

import std.container;
import std.algorithm;

class QuadtreeNode
{
    package
    {
        QuadtreeNode _parent;
        Quadtree _quadtree;
        bool _hasChildren;
        QuadtreeNode[4] _children;
        QuadtreeOccupant[] _occupants;
        FloatRect _region;
        int _level;
        int _numOccupantsBelow;
    }

    this()
    {
        _parent = null;
        _quadtree = null;
        _hasChildren = false;
        _region = FloatRect.init;
        _level = int.init;
        _numOccupantsBelow = 0;
    }

    this(ref const(FloatRect) region, int level, QuadtreeNode parent, Quadtree quadtree)
    {
        create(region, level, parent, quadtree);
    }
    
    /++
     + Rest this node to its initially constructed state.
     +/
    void create(ref const(FloatRect) region, int level, QuadtreeNode parent, Quadtree quadtree)
    {
        _hasChildren = false;
        _region = region;
        _level = level;
        _parent = parent;
        _quadtree = quadtree;
        _numOccupantsBelow = 0;
    }

    /*void create(ref const(FloatRect) region, int level, QuadtreeNode parent, Quadtree quadtree)
    {
        _hasChildren = false;

        _region = region;
        _level = level;
        _parent = parent;
        _quadtree = quadtree;
    }*/

    @property const(Quadtree) quadtree()
    {
        return _quadtree;
    }

    void add(QuadtreeOccupant oc)
    {
        assert(oc !is null);

        _numOccupantsBelow++;

        // See if the occupant fits into any children (if there are any)
        if (_hasChildren)
        {
            if (addToChildren(oc))
                return; // Fit, can stop
        }
        else
        {
            // Check if we need a new partition
            if (_occupants.length >= _quadtree.maxNumNodeOccupants
                && _level < _quadtree.maxLevels)
            {
                partition();

                if (addToChildren(oc))
                    return;
            }
        }

        // Did not fit in anywhere, add to this level, even if it goes over the maximum size
        addToThisLevel(oc);
    }

    @property const(FloatRect) region() const
    {
        return _region;
    }

    void getAllOccupantsBelow(ref QuadtreeOccupant[] occupants)
    {
        // Iteratively parse subnodes in order to collect all occupants below this node
        DList!(QuadtreeNode) open;

        open.insertBack(this);

        while (!open.empty())
        {
            // Depth-first (results in less memory usage), remove objects from open list
            QuadtreeNode currentNode = open.back();
            open.removeBack();

            // Get occupants
            foreach (ref occupant; _occupants)
            {
                if (occupant)
                    // Add to this node
                    occupants ~= occupant;
            }

            // If the node has children, add them to the open list
            if (currentNode._hasChildren)
                for (int i = 0; i < 4; i++)
                    open.insertBack(currentNode._children[i]);
        }
    }

    @property int numOccupantsBelow()
    {
        return _numOccupantsBelow;
    }

    /*void pruneDeadReferences()
    {
        //use http://forum.dlang.org/post/mailman.564.1336706406.24740.digitalmars-d-learn@puremagic.com
        foreach (occupant; _occupants)
        {
            if (occupant is null)
                _occupants.remove(occupant);
        }

        if (_hasChildren)
            for (int i = 0; i < 4; i++)
                _children[i].pruneDeadReferences();
    }*/

package:

    void getPossibleOccupantPosition(ref QuadtreeOccupant oc, out Vector2i point)
    {
        // Compare the center of the AABB of the occupant to that of this node to determine
        // which child it may (possibly, not certainly) fit in
        const(Vector2f) occupantCenter = rectCenter(oc.getAABB());
        const(Vector2f) nodeRegionCenter = rectCenter(_region);

        point.x = occupantCenter.x > nodeRegionCenter.x ? 1 : 0;
        point.y = occupantCenter.y > nodeRegionCenter.y ? 1 : 0;
    }

    void addToThisLevel(QuadtreeOccupant oc) {
        oc._quadtreeNode = this;

        if (_occupants.countUntil(oc) >= 0)
            return;

        _occupants ~= oc;
    }

    // Returns true if occupant was added to children
    bool addToChildren(QuadtreeOccupant oc) {
        assert(_hasChildren);

        Vector2i position;

        getPossibleOccupantPosition(oc, position);

        QuadtreeNode pChild = _children[position.x + position.y * 2];

        // See if the occupant fits in the child at the selected position
        if (rectContains(pChild._region, oc.getAABB())) {
            // Fits, so can add to the child and finish
            pChild.add(oc);

            return true;
        }

        return false;
    }

    void destroyChildren() {
        for (int i = 0; i < 4; i++)
            _children[i] = null;

        _hasChildren = false;
    }

    void getOccupants(ref QuadtreeOccupant[] occupants) {
        // Iteratively parse subnodes in order to collect all occupants below this node
        DList!(QuadtreeNode) open;

        open.insertBack(this);

        while (!open.empty()) {
            // Depth-first (results in less memory usage), remove objects from open list
            QuadtreeNode currentNode = open.back();
            open.removeBack();

            // Get occupants
            foreach (occupant; currentNode._occupants)
            {
                if (occupant) {
                    // Assign new node
                    occupant._quadtreeNode = this;

                    // Add to this node
                    occupants ~= occupant;
                }
            }

            // If the node has children, add them to the open list
            if (currentNode._hasChildren)
                for (int i = 0; i < 4; i++)
                    open.insertBack(currentNode._children[i]);
        }
    }

    void partition() {
        assert(!_hasChildren);

        Vector2f halfRegionDims = rectHalfDims(_region);
        Vector2f regionLowerBound = rectLowerBound(_region);
        Vector2f regionCenter = rectCenter(_region);

        int nextLowerLevel = _level - 1;

        for (int x = 0; x < 2; x++)
        {
            for (int y = 0; y < 2; y++)
            {
                Vector2f offset = Vector2f(x * halfRegionDims.x, y * halfRegionDims.y);

                FloatRect childAABB = rectFromBounds(regionLowerBound + offset, regionCenter + offset);

                // Scale up AABB by the oversize multiplier
                Vector2f newHalfDims = rectHalfDims(childAABB);
                Vector2f center = rectCenter(childAABB);
                childAABB = rectFromBounds(center - newHalfDims, center + newHalfDims);

                _children[x + y * 2] = new QuadtreeNode(childAABB, nextLowerLevel, this, _quadtree);
            }
        }

        _hasChildren = true;
    }

    void merge() {
        if (_hasChildren) {
            // Place all occupants at lower levels into this node
            getOccupants(_occupants);

            destroyChildren();
        }
    }

    void update(QuadtreeOccupant oc) {
        if (oc is null)
            return;

        if (_occupants.length > 0)
            // Remove, may be re-added to this node later
            _occupants.removeElement(oc);

        // Propogate upwards, looking for a node that has room (the current one may still have room)
        QuadtreeNode node = this;

        while (node !is null) {
            node._numOccupantsBelow--;

            // If has room for 1 more, found a spot
            if (rectContains(node._region, oc.getAABB()))
                break;

            node = node._parent;
        }

        // If no node that could contain the occupant was found, add to outside root set
        if (node is null) {
            assert(_quadtree !is null);

            if (_quadtree._outsideRoot.countUntil(oc) >= 0)
                return;

            _quadtree._outsideRoot ~= oc;

            oc._quadtreeNode = null;
        }
        else
        {
            // Add to the selected node
            node.add(oc);
        }
    }

    void remove(QuadtreeOccupant oc) {
        assert(_occupants.length > 0);

        // Remove from node
        _occupants.removeElement(oc);

        if (oc is null)
            return;

        // Propogate upwards, merging if there are enough occupants in the node
        QuadtreeNode node = this;

        while (node !is null) {
            node._numOccupantsBelow--;

            if (node._numOccupantsBelow >= _quadtree.minNumNodeOccupants) {
                node.merge();

                break;
            }

            node = node._parent;
        }
    }

    void removeForDeletion(ref QuadtreeOccupant[] occupants) {
        // Iteratively parse subnodes in order to collect all occupants below this node
        DList!(QuadtreeNode) open;

        open.insertBack(this);

        while (!open.empty()) {
            // Depth-first (results in less memory usage), remove objects from open list
            QuadtreeNode currentNode = open.back();
            open.removeBack();

            // Get occupants
            foreach (occupant; currentNode._occupants)
            {
                if (occupant) {
                    // Since will be deleted, remove the reference
                    occupant._quadtreeNode = null;

                    // Add to this node
                    occupants ~= occupant;
                }
            }

            // If the node has children, add them to the open list
            if (currentNode._hasChildren)
            for (int i = 0; i < 4; i++)
                open.insertBack(currentNode._children[i]);
        }
    }
}
