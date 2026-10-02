import { compile } from 'json-schema-to-typescript'
import { mkdir, readFile, readdir, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.dirname(fileURLToPath(import.meta.url))
const schemasDir = path.join(root, '..', '..', 'schemas', 'schemas')
const outDir = path.join(root, '..', 'src', 'generated')

async function main() {
  await mkdir(outDir, { recursive: true })
  const files = (await readdir(schemasDir)).filter((f) => f.endsWith('.schema.json'))

  for (const file of files) {
    const schema = JSON.parse(await readFile(path.join(schemasDir, file), 'utf-8'))
    const name = path.basename(file, '.schema.json')
    const ts = await compile(schema, name, { bannerComment: '' })
    await writeFile(path.join(outDir, `${name}.ts`), ts)
    console.log(`generated ${name}.ts`)
  }

  if (files.length === 0) {
    console.log('no schemas found in packages/schemas/schemas yet')
  }
}

main()
