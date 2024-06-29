type UnionToIntersection<U> = (U extends any ? (k: U) => void : never) extends (
    k: infer I
) => void
    ? I
    : never

// Example usage
type UnionType = { a: number } | { b: string } | { c: boolean }

export type IntersectionType = UnionToIntersection<UnionType>
