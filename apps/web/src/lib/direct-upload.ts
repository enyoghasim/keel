import { DirectUpload } from '@rails/activestorage'

const DIRECT_UPLOAD_URL = '/rails/active_storage/direct_uploads'

// Uploads straight to Active Storage and resolves with the blob's signed_id,
// the only thing Api::CompaniesController#create accepts for roster_csv/handbook —
// it never receives the raw file itself.
export function uploadFile(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const upload = new DirectUpload(file, DIRECT_UPLOAD_URL)
    upload.create((error, blob) => {
      if (error) {
        reject(error)
      } else {
        resolve(blob!.signed_id)
      }
    })
  })
}
