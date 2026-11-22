import os
import re
import numpy as np

class PythonGlobeReader:
    TILE_COLUMNS = 10800
    TILE_ROWS_SMALL = 4800
    TILE_ROWS_LARGE = 6000
    
    GRID_COLUMNS = 4 * TILE_COLUMNS  # 43200
    GRID_ROWS = 2 * TILE_ROWS_LARGE + 2 * TILE_ROWS_SMALL  # 21600
    
    FILE_SIZE_SMALL = 103680000  # 10800 * 4800 * 2 bytes
    FILE_SIZE_LARGE = 129600000  # 10800 * 6000 * 2 bytes
    
    ELEVATION_INVALID = 3.4028234663852886e+38
    ELEVATION_OCEAN = -500.0

    def __init__(self, data_dir):
        self.data_dir = data_dir
        self.files = {}
        self.tile_cache = {}  # In-memory cache for loaded tiles
        self._open_files()

    def _open_files(self):
        # Strictly map row/col (0-3) to official GLOBE 16 tile letters (a through p)
        for r_idx in range(4):
            for c_idx in range(4):
                letter = chr(ord('a') + (r_idx * 4 + c_idx))
                candidates = []
                for filename in os.listdir(self.data_dir):
                    lower = filename.lower()
                    m = re.fullmatch(rf"{letter}(\d+)([gb])", lower)
                    if not m:
                        continue
                    candidate_path = os.path.join(self.data_dir, filename)
                    if os.path.isfile(candidate_path) and os.path.getsize(candidate_path) in (
                        self.FILE_SIZE_SMALL,
                        self.FILE_SIZE_LARGE,
                    ):
                        rev = int(m.group(1))
                        ext_rank = 1 if m.group(2) == "g" else 0
                        candidates.append(((rev, ext_rank, lower), candidate_path))

                if candidates:
                    _, best_path = max(candidates, key=lambda item: item[0])
                    self.files[(r_idx, c_idx)] = best_path

        print(f"[GLOBE Reader] Successfully loaded {len(self.files)}/16 elevation tiles.")

    def get_elevation_grid(self, bounds_latlon=None):
        """
        Loads the entire grid or a subgrid into a 2D numpy array 
        matching row/col indexing for contour-flight.
        """
        pass

    def get_elevation(self, lon, lat):
        # Normalize longitude/latitude to grid col/row (Corrected latitude formula: 90.0 - lat)
        grid_col = int(self.GRID_COLUMNS * (lon + 180.0) / 360.0)
        grid_row = int(self.GRID_ROWS * (90.0 - lat) / 180.0)
        
        grid_col = grid_col % self.GRID_COLUMNS
        grid_row = grid_row % self.GRID_ROWS
        
        file_col = grid_col // self.TILE_COLUMNS
        file_col_offset = grid_col % self.TILE_COLUMNS
        
        if grid_row < self.TILE_ROWS_SMALL:
            file_row, file_row_offset = 0, grid_row
        elif grid_row < self.TILE_ROWS_SMALL + self.TILE_ROWS_LARGE:
            file_row, file_row_offset = 1, grid_row - self.TILE_ROWS_SMALL
        elif grid_row < self.TILE_ROWS_SMALL + 2 * self.TILE_ROWS_LARGE:
            file_row, file_row_offset = 2, grid_row - (self.TILE_ROWS_SMALL + self.TILE_ROWS_LARGE)
        else:
            file_row, file_row_offset = 3, grid_row - (self.TILE_ROWS_SMALL + 2 * self.TILE_ROWS_LARGE)
            
        tile_key = (file_row, file_col)
        if tile_key not in self.files:
            return self.ELEVATION_INVALID
            
        if tile_key not in self.tile_cache:
            tile_rows = self.TILE_ROWS_LARGE if file_row in (1, 2) else self.TILE_ROWS_SMALL
            with open(self.files[tile_key], "rb") as f:
                raw_data = f.read()
                arr = np.frombuffer(raw_data, dtype=np.int16).reshape((tile_rows, self.TILE_COLUMNS))
                self.tile_cache[tile_key] = arr
                
        elevation = self.tile_cache[tile_key][file_row_offset, file_col_offset]
        return float(elevation)
