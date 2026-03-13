package game101

import "sort"

func IsValidGroup(tiles []Tile) bool {
	if len(tiles) < 3 || len(tiles) > 4 {
		return false
	}

	value := 0
	colorSeen := map[string]bool{}

	for i, t := range tiles {
		if t.IsFakeOkey {
			continue
		}
		if i == 0 || value == 0 {
			value = t.Value
		}
		if t.Value != value {
			return false
		}
		if colorSeen[t.Color] {
			return false
		}
		colorSeen[t.Color] = true
	}

	return true
}

func IsValidRun(tiles []Tile) bool {
	if len(tiles) < 3 {
		return false
	}

	color := ""
	values := make([]int, 0, len(tiles))
	jokerCount := 0

	for _, t := range tiles {
		if t.IsOkey || t.IsFakeOkey {
			jokerCount++
			continue
		}
		if color == "" {
			color = t.Color
		}
		if t.Color != color {
			return false
		}
		values = append(values, t.Value)
	}

	if len(values) == 0 {
		return true
	}

	sort.Ints(values)

	requiredJokers := 0
	for i := 1; i < len(values); i++ {
		diff := values[i] - values[i-1]
		if diff <= 0 {
			return false
		}
		if diff > 1 {
			requiredJokers += diff - 1
		}
	}

	return requiredJokers <= jokerCount
}

func SumTiles(tiles []Tile) int {
	total := 0
	for _, t := range tiles {
		if t.IsOkey || t.IsFakeOkey {
			continue
		}
		total += t.Value
	}
	return total
}

func CanOpenWith101(groups [][]Tile) bool {
	total := 0
	for _, g := range groups {
		if !(IsValidGroup(g) || IsValidRun(g)) {
			return false
		}
		total += SumTiles(g)
	}
	return total >= 101
}

func CountPairs(tiles []Tile) int {
	type key struct {
		color string
		value int
		kind  string
	}
	counts := map[key]int{}
	for _, t := range tiles {
		k := key{color: t.Color, value: t.Value, kind: t.Kind}
		counts[k]++
	}
	pairs := 0
	for _, c := range counts {
		pairs += c / 2
	}
	return pairs
}

func CanOpenWithPairs(tiles []Tile) bool {
	return CountPairs(tiles) >= 5
}

func PenaltyNormal(remaining []Tile) int {
	total := 0
	for _, t := range remaining {
		if t.IsOkey || t.IsFakeOkey {
			continue
		}
		total += t.Value
	}
	return total
}

func PenaltyNeverOpened() int {
	return 202
}

func PenaltyDoubled(remaining []Tile) int {
	return PenaltyNormal(remaining) * 2
}
