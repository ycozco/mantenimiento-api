import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

import { PullChangesQueryDto, PushOperationDto } from './push-operation.dto';

describe('sync request validation', () => {
  it('accepts only bounded encrypted envelopes and converts the pull limit', async () => {
    const push = plainToInstance(PushOperationDto, {
      operationId: '7ac5ff64-e301-4f2e-a451-349b617a42ec',
      entityType: 'maintenance_visit',
      entityId: 'ecc486e6-c62e-4be5-9cd6-b72ef11cc902',
      schemaVersion: 1,
      nonce: 'MTIzNDU2Nzg5MDEy',
      ciphertext: 'MTIzNDU2Nzg5MDEyMzQ1Ng==',
    });
    expect(await validate(push)).toHaveLength(0);

    const pull = plainToInstance(PullChangesQueryDto, { cursor: '12', limit: '20' });
    expect(await validate(pull)).toHaveLength(0);
    expect(pull.limit).toBe(20);
  });

  it('rejects plaintext-shaped payloads, malformed IDs, and oversized envelopes', async () => {
    const invalid = plainToInstance(PushOperationDto, {
      operationId: 'not-a-uuid',
      entityType: 'Maintenance Visit',
      entityId: 'local-id',
      schemaVersion: 1,
      nonce: 'short',
      ciphertext: 'this is not base64',
    });
    expect((await validate(invalid)).length).toBeGreaterThan(0);

    const oversized = plainToInstance(PushOperationDto, {
      operationId: '7ac5ff64-e301-4f2e-a451-349b617a42ec',
      entityType: 'maintenance_visit',
      entityId: 'ecc486e6-c62e-4be5-9cd6-b72ef11cc902',
      schemaVersion: 1,
      nonce: 'MTIzNDU2Nzg5MDEy',
      ciphertext: 'A'.repeat(70004),
    });
    expect((await validate(oversized)).some((error) => error.property === 'ciphertext')).toBe(true);
  });
});
