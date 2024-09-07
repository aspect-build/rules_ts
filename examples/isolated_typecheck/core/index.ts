/**
 * A file with some non-trivial types, so type-checking it may take some time.
 * This helps to motivate the example: we'd like to be able to type-check the frontend and backend in parallel with this file.
 */
type UnionToIntersection<U> = (U extends any ? (k: U) => void : never) extends (
    k: infer I
) => void
    ? I
    : never

// Example usage
type UnionType = { a: number } | { b: string } | { c: boolean }

export type IntersectionType = UnionToIntersection<UnionType>

export const MyIntersectingValue: IntersectionType = {
    a: 1,
    b: '2',
    c: true,
}
