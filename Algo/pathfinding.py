import heapq
import math

class PathFinder:
    def __init__(self, floors, connections):
        self.floors = floors
        self.connections = connections 
        self.rows = len(floors[0])
        self.cols = len(floors[0][0])
        
        # Calculate distance map
        self.dist_map = self.generate_distance_map(floors[0])

    def generate_distance_map(self, grid):
        """Calculates exact distance to nearest wall."""
        rows, cols = len(grid), len(grid[0])
        dist_map = [[0.0 for _ in range(cols)] for _ in range(rows)]
        
        walls = []
        for r in range(rows):
            for c in range(cols):
                if grid[r][c] == 1:
                    walls.append((r, c))
        
        for r in range(rows):
            for c in range(cols):
                if grid[r][c] == 0:
                    if not walls:
                        dist_map[r][c] = float('inf')
                    else:
                        min_dist = min([math.sqrt((r-wr)**2 + (c-wc)**2) for wr, wc in walls])
                        dist_map[r][c] = min_dist
                else:
                    dist_map[r][c] = 0.0
        return dist_map

    def heuristic(self, a, b):
        return math.sqrt((a[1] - b[1])**2 + (a[2] - b[2])**2) + (abs(a[0] - b[0]) * 5)

    def get_neighbors(self, node):
        neighbors = []
        f, r, c = node 
        moves = [
            (-1, 0, 1.0), (1, 0, 1.0), (0, -1, 1.0), (0, 1, 1.0),      
            (-1, -1, 1.414), (-1, 1, 1.414), (1, -1, 1.414), (1, 1, 1.414) 
        ]
        
        for dr, dc, base_cost in moves:
            nr, nc = r + dr, c + dc
            if 0 <= nr < self.rows and 0 <= nc < self.cols:
                if self.floors[f][nr][nc] == 1: continue 

                # SMART 1-BLOCK SAFETY
                # We use 1.2 to give just a tiny bit of breathing room so it doesn't
                # look like it's scraping the paint off the wall.
                distance_to_wall = self.dist_map[nr][nc]
                penalty = 0
                
                if distance_to_wall < 1.2:
                    penalty = 10.0 
                
                neighbors.append(((f, nr, nc), base_cost + penalty))
                    
        if node in self.connections:
            neighbors.append((self.connections[node], 1.0))
        return neighbors

    def is_line_clear(self, floor_idx, start, end):
        r0, c0 = start[1], start[2]
        r1, c1 = end[1], end[2]
        steps = int(max(abs(r1 - r0), abs(c1 - c0)) * 2) 
        if steps == 0: return True

        for i in range(1, steps + 1):
            t = i / steps
            r_check = int(r0 + (r1 - r0) * t)
            c_check = int(c0 + (c1 - c0) * t)
            
            if self.floors[floor_idx][r_check][c_check] == 1: return False
            
            # Smoothing Block:
            # We allow the line to get very close (1.05) but not touch.
            if self.dist_map[r_check][c_check] < 1.05: return False
                
        return True

    def smooth_path(self, original_path):
        if not original_path: return []
        clean_path = [original_path[0]]
        current_idx = 0
        while current_idx < len(original_path) - 1:
            found_shortcut = False
            for check_idx in range(len(original_path) - 1, current_idx, -1):
                if original_path[current_idx][0] == original_path[check_idx][0]:
                    if self.is_line_clear(original_path[current_idx][0], 
                                        original_path[current_idx], 
                                        original_path[check_idx]):
                        clean_path.append(original_path[check_idx])
                        current_idx = check_idx
                        found_shortcut = True
                        break
            if not found_shortcut:
                current_idx += 1
                clean_path.append(original_path[current_idx])
        return clean_path

    def find_path(self, start, goal):
        raw_path = self._a_star_raw(start, goal)
        if raw_path: return self.smooth_path(raw_path)
        return None

    def _a_star_raw(self, start, goal):
        open_set = []
        heapq.heappush(open_set, (0, start))
        came_from = {}
        g_score = {start: 0}
        f_score = {start: self.heuristic(start, goal)}

        while open_set:
            current_f, current = heapq.heappop(open_set)
            if current == goal: return self.reconstruct_path(came_from, current)

            for neighbor, cost in self.get_neighbors(current):
                tentative_g_score = g_score[current] + cost
                if neighbor not in g_score or tentative_g_score < g_score[neighbor]:
                    came_from[neighbor] = current
                    g_score[neighbor] = tentative_g_score
                    f = tentative_g_score + self.heuristic(neighbor, goal)
                    f_score[neighbor] = f
                    heapq.heappush(open_set, (f, neighbor))
        return None 

    def reconstruct_path(self, came_from, current):
        total_path = [current]
        while current in came_from:
            current = came_from[current]
            total_path.append(current)
        return total_path[::-1]
    