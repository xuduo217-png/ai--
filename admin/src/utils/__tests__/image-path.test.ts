import assert from 'node:assert/strict'
import { extractUploadPath } from '../image'

assert.equal(extractUploadPath('/uploads/example.jpg'), '/uploads/example.jpg')
assert.equal(
  extractUploadPath('https://assets.example.com/uploads/example.jpg'),
  '/uploads/example.jpg'
)
assert.equal(
  extractUploadPath('http://192.168.1.8:3000/uploads/nested/example.png'),
  '/uploads/nested/example.png'
)
assert.equal(
  extractUploadPath('https://assets.example.com/static/example.jpg'),
  'https://assets.example.com/static/example.jpg'
)
assert.equal(extractUploadPath('  /uploads/spaces.jpg  '), '/uploads/spaces.jpg')
assert.equal(extractUploadPath(undefined), undefined)

console.log('image-path tests passed')
