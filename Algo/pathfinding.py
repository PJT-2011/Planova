import heapq
import math

class PathFinder:
    def __init__(self, floors, connections=None):
        """
        Initializes the PathFinder with grid data.
        :param floors: A list of 2D arrays (0 = floor, 1 = wall).
        :param connections: Optional dictionary for elevators/stairs between floors.
        """
        self.floors = floors
        self.connections = connections if connections else {}
        self.rows = len(floors[0])
        self.cols = len(floors[0][0])

    def heuristic(self, a, b):
        """Standard Euclidean distance for A* priority."""
        return math.sqrt((a[1] - b[1])**2 + (a[2] - b[2])**2)

    def is_line_clear(self, floor_idx, start, end):
        """
        Collision Detection: Checks if a straight line between two points 
        hits a wall (1). Uses a high-density step check to prevent 'ghosting'.
        """
        r0, c0 = start[1], start[2]
        r1, c1 = end[1], end[2]
        dist = math.sqrt((r1 - r0)**2 + (c1 - c0)**2)
        
        # Check every 0.5 pixels along the line
        steps = int(dist * 2) 
        if steps == 0: return True

        for i in range(steps + 1):
            t = i / steps
            curr_r = int(r0 + (r1 - r0) * t)
            curr_c = int(c0 + (c1 - c0) * t)
            
            # Boundary and collision check
            if 0 <= curr_r < self.rows and 0 <= curr_c < self.cols:
                if self.floors[floor_idx][curr_r][curr_c] == 1:
                    return False
            else:
                return False
        return True

    def get_neighbors(self, node):
        """Returns valid adjacent walkable tiles."""
        neighbors = []
        f, r, c = node 
        # Supports 8-way movement (Horizontal, Vertical, Diagonal)
        for dr, dc in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,1),(-1,1),(1,-1)]:
            nr, nc = r + dr, c + dc
            if 0 <= nr < self.rows and 0 <= nc < self.cols:
                if self.floors[f][nr][nc] == 0:
                    cost = 1.414 if abs(dr) + abs(dc) == 2 else 1.0
                    neighbors.append(((f, nr, nc), cost))
        return neighbors

    def find_path(self, start, goal):
        """Executes A* search and returns a smoothed list of coordinates."""
        open_set = []
        heapq.heappush(open_set, (0, start))
        came_from = {}
        g_score = {start: 0}
        
        while open_set:
            _, current = heapq.heappop(open_set)

            if current == goal:
                path = [current]
                while current in came_from:
                    current = came_from[current]
                    path.append(current)
                # Reverse and apply smoothing to reduce unnecessary zig-zags
                return self.smooth_path(path[::-1])

            for neighbor, cost in self.get_neighbors(current):
                tentative_g = g_score[current] + cost
                if neighbor not in g_score or tentative_g < g_score[neighbor]:
                    came_from[neighbor] = current
                    g_score[neighbor] = tentative_g
                    f_score = tentative_g + self.heuristic(neighbor, goal)
                    heapq.heappush(open_set, (f_score, neighbor))
        return None

    def smooth_path(self, path):
        """Path Post-Processing: Removes redundant waypoints for a direct line-of-sight."""
        if not path: return []
        smooth = [path[0]]
        curr = 0
        while curr < len(path) - 1:
            best = curr + 1
            # Look as far ahead as possible to see if a straight line is clear
            for check in range(len(path) - 1, curr + 1, -1):
                if self.is_line_clear(path[curr][0], path[curr], path[check]):
                    best = check
                    break
            smooth.append(path[best])
            curr = best
        return smooth
