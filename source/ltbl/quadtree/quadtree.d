module ltbl.quadtree.quadtree;

import ltbl;

import dsfml.graphics;

import std.container;

// Base class for dynamic and static Quadtree types
class Quadtree
{
    package
    {
        QuadtreeOccupant[] _outsideRoot;
        QuadtreeNode _rootNode;
    }

    public
    {
        size_t minNumNodeOccupants;
        size_t maxNumNodeOccupants;
        size_t maxLevels;

        float oversizeMultiplier;
    }

    this()
    {
        minNumNodeOccupants = 3;
        maxNumNodeOccupants = 6;
        maxLevels = 40;
        oversizeMultiplier = 1.0f;
    }

    /*@property auto dup() {
        auto newTree = new Quadtree();
        newTree.minNumNodeOccupants = minNumNodeOccupants;
        newTree.maxNumNodeOccupants = maxNumNodeOccupants;
        newTree.maxLevels = maxLevels;
        newTree.oversizeMultiplier = oversizeMultiplier;

        newTree._outsideRoot = _outsideRoot;

        if (_rootNode !is null) {
            newTree._rootNode.reset = new QuadtreeNode();

            recursiveCopy(newTree._rootNode, _rootNode, null);
        }
    }*/

    abstract void add(QuadtreeOccupant oc);

    /*void pruneDeadReferences() {
        for (occupant; _outsideRoot)
        {
            if ((*it) == nullptr)
                it++;
            else
                it = _outsideRoot.erase(it);
        }

        if (_rootNode !is null)
            _rootNode.pruneDeadReferences();
    }*/

    void queryRegion(QuadtreeOccupant[] result, in FloatRect region)
    {
        // Query outside root elements
        foreach(occupant; _outsideRoot)
        {
            FloatRect r = occupant.getAABB();

            if (occupant !is null && region.intersects(occupant.getAABB()))
            {
                // Intersects, add to list
                result ~= occupant;
            }
        }

        DList!(QuadtreeNode) open;

        open.insertBack(_rootNode);

        while (!open.empty())
        {
            // Depth-first (results in less memory usage), remove objects from open list
            QuadtreeNode current = open.back();
            open.removeBack();

            if (region.intersects(current._region))
            {
                foreach(occupant; current._occupants)
                {
                    if (occupant !is null && region.intersects(occupant.getAABB()))
                    {
                        // Visible, add to list
                        result ~= occupant;
                    }
                }

                // Add children to open list if they intersect the region
                if (current._hasChildren)
                {
                    for (int i = 0; i < 4; i++)
                    {
                        if (current._children[i].numOccupantsBelow() != 0)
                        {
                            open.insertBack(current._children[i]);
                        }
                    }
                }
            }
        }
    }


    void queryPoint(QuadtreeOccupant[] result, ref const(Vector2f) p) {
        // Query outside root elements
        foreach(occupant; _outsideRoot)
        {
            if (occupant !is null && occupant.getAABB().contains(p))
                // Intersects, add to list
                result ~= occupant;
        }

        DList!(QuadtreeNode) open;

        open.insertBack(_rootNode);

        while (!open.empty())
        {
            // Depth-first (results in less memory usage), remove objects from open list
            QuadtreeNode current = open.back();
            open.removeBack();

            if (current._region.contains(p))
            {
                foreach(occupant; current._occupants)
                {
                    if (occupant !is null && occupant.getAABB().contains(p))
                        // Visible, add to list
                        result ~= occupant;
                }

                // Add children to open list if they intersect the region
                if (current._hasChildren)
                {
                    for(int i = 0; i < 4; i++)
                    {
                        if (current._children[i].numOccupantsBelow() != 0)
                        {
                            open.insertBack(current._children[i]);
                        }
                    }
                }
            }
        }
    }

    void queryShape(QuadtreeOccupant[] result, ref ConvexShape shape)
    {
        // Query outside root elements
        foreach(occupant; _outsideRoot)
        {
            if (occupant !is null && shapeIntersection(shapeFromRect(occupant.getAABB()), shape))
                // Intersects, add to list
                result ~= occupant;
        }

        DList!(QuadtreeNode) open;

        open.insertBack(_rootNode);

        while (!open.empty())
        {
            // Depth-first (results in less memory usage), remove objects from open list
            QuadtreeNode current = open.back();
            open.removeBack();

            if (shapeIntersection(shapeFromRect(current._region), shape))
            {
                foreach(occupant; current._occupants) {
                    ConvexShape r = shapeFromRect(occupant.getAABB());

                    if (occupant !is null && shapeIntersection(shapeFromRect(occupant.getAABB()), shape))
                        // Visible, add to list
                        result ~= occupant;
                }

                // Add children to open list if they intersect the region
                if (current._hasChildren)
                {
                    for (int i = 0; i < 4; i++)
                    {
                        if (current._children[i].numOccupantsBelow() != 0)
                        {
                            open.insertBack(current._children[i]);
                        }
                    }
                }
            }
        }
    }


protected:
    // Called whenever something is removed, an action can be defined by derived classes
    // Defaults to doing nothing
    void onRemoval() {}

    void setQuadtree(ref QuadtreeOccupant oc) {
        oc._quadtree = this;
    }

    void recursiveCopy(ref QuadtreeNode thisNode, ref QuadtreeNode otherNode, ref QuadtreeNode thisParent) {
        thisNode._hasChildren = otherNode._hasChildren;
        thisNode._level = otherNode._level;
        thisNode._numOccupantsBelow = otherNode._numOccupantsBelow;
        thisNode._occupants = otherNode._occupants;
        thisNode._region = otherNode._region;

        thisNode._parent = thisParent;

        thisNode._quadtree = this;

        if (thisNode._hasChildren)
        {
            for (int i = 0; i < 4; i++) {
                thisNode._children[i] = new QuadtreeNode();

                recursiveCopy(thisNode._children[i], otherNode._children[i], thisNode);
            }
        }
    }
}
