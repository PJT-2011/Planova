import heapq
import math

class DijkstraPathFinder:
    def __init__(self, floors):
        """
        Dijkstra-based PathFinder with A* Heuristic 'Help' for speed.
        """
        self.floors = floors
        self.rows = len(floors[0])
        self.cols = len(floors[0][0])
        
        # This is the 'A* Help'. 
        # 1.0 = Pure A* # 0.0 = Pure Dijkstra
        # 1.2 = Fast 'Greedy' Search (Recommended)
        self.heuristic_weight = 1.2

    def get_distance(self, a, b):
        """Calculates Euclidean distance (the 'GPS' help)."""
        return math.sqrt((a[1] - b[1])**2 + (a[2] - b[2])**2)

    def is_line_clear(self, floor_idx, start, end):
        """
        Collision Guard: Checks every 0.5 pixels to ensure no ghosting.
        """
        r0, c0 = start[1], start[2]
        r1, c1 = end[1], end[2]
        dist = self.get_distance(start, end)
        steps = int(dist * 2)
        if steps == 0: return True

        for i in range(steps + 1):
            t = i / steps
            curr_r = int(r0 + (r1 - r0) * t)
            curr_c = int(c0 + (c1 - c0) * t)
            if 0 <= curr_r < self.rows and 0 <= curr_c < self.cols:
                if self.floors[floor_idx][curr_r][curr_c] == 1:
                    return False
        return True

    def get_neighbors(self, node):
        """Standard 8-way movement logic."""
        neighbors = []
        f, r, c = node 
        for dr, dc in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,1),(-1,1),(1,-1)]:
            nr, nc = r + dr, c + dc
            if 0 <= nr < self.rows and 0 <= nc < self.cols:
                if self.floors[f][nr][nc] == 0:
                    # Diagonal moves cost more (sqrt 2)
                    weight = 1.414 if abs(dr) + abs(dc) == 2 else 1.0
                    neighbors.append(((f, nr, nc), weight))
        return neighbors

    def find_path(self, start, goal):
        """Modified Dijkstra with A* Heuristic for faster convergence."""
        pq = [(0, 0, start)] # (Priority, Current_Actual_Dist, Node)
        came_from = {}
        g_score = {start: 0}
        
        while pq:
            _, current_g, current = heapq.heappop(pq)

            if current == goal:
                path = [current]
                while current in came_from:
                    current = came_from[current]
                    path.append(current)
                return self.smooth_path(path[::-1])

            for neighbor, weight in self.get_neighbors(current):
                tentative_g = current_g + weight
                
                if neighbor not in g_score or tentative_g < g_score[neighbor]:
                    came_from[neighbor] = current
                    g_score[neighbor] = tentative_g
                    
                    # This is where Dijkstra gets 'help' from A*
                    # f = actual distance + (estimated distance * weight)
                    h = self.get_distance(neighbor, goal) * self.heuristic_weight
                    f_score = tentative_g + h
                    
                    heapq.heappush(pq, (f_score, tentative_g, neighbor))
        return None

    def smooth_path(self, path):
        """Turns the zig-zag grid movement into direct lines."""
        if not path: return []
        smooth = [path[0]]
        curr = 0
        while curr < len(path) - 1:
            best = curr + 1
            for check in range(len(path) - 1, curr + 1, -1):
                if self.is_line_clear(path[curr][0], path[curr], path[check]):
                    best = check
                    break
            smooth.append(path[best])
            curr = best
        return smooth