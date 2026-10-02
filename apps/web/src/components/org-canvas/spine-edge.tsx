import { BaseEdge, type EdgeProps } from '@xyflow/react'

const DROP = 14
const SPINE_OFFSET = 14

// The connector for a stacked report: down from the manager, across to a spine
// just left of the column, down it, and in to the card's left side. Every
// report in the column shares the spine, so a dozen of them read as one line.
export function SpineEdge({ id, sourceX, sourceY, targetX, targetY, markerEnd, style }: EdgeProps) {
  const spineX = targetX - SPINE_OFFSET
  const path = `M ${sourceX},${sourceY} L ${sourceX},${sourceY + DROP} L ${spineX},${sourceY + DROP} L ${spineX},${targetY} L ${targetX},${targetY}`

  return <BaseEdge id={id} path={path} markerEnd={markerEnd} style={style} />
}
