import { DirectUpload } from '@rails/activestorage'
import { describe, expect, it, vi } from 'vitest'
import { uploadFile } from './directUpload'

vi.mock('@rails/activestorage', () => ({
  DirectUpload: vi.fn(),
}))

describe('uploadFile', () => {
  it('posts to the Active Storage direct-upload endpoint and resolves with the blob signed_id', async () => {
    vi.mocked(DirectUpload).mockImplementation(function (
      this: DirectUpload,
      file: File,
      url: string,
    ) {
      Object.assign(this, {
        file,
        url,
        create: (callback: (error: Error | null, blob?: { signed_id: string }) => void) =>
          callback(null, { signed_id: 'abc123' }),
      })
    } as unknown as typeof DirectUpload)

    const file = new File(['name,email'], 'roster.csv', { type: 'text/csv' })
    await expect(uploadFile(file)).resolves.toBe('abc123')
    expect(DirectUpload).toHaveBeenCalledWith(file, '/rails/active_storage/direct_uploads')
  })

  it('rejects with the upload error on failure', async () => {
    vi.mocked(DirectUpload).mockImplementation(function (this: DirectUpload) {
      Object.assign(this, {
        create: (callback: (error: Error | null) => void) => callback(new Error('upload failed')),
      })
    } as unknown as typeof DirectUpload)

    const file = new File(['%PDF-'], 'handbook.pdf', { type: 'application/pdf' })
    await expect(uploadFile(file)).rejects.toThrow('upload failed')
  })
})
