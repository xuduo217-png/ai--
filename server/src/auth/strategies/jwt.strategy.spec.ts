import { UnauthorizedException } from '@nestjs/common';
import { JwtStrategy } from './jwt.strategy';

jest.mock('uuid', () => ({ v4: jest.fn(() => 'test-id') }));

describe('doctor JWT account status', () => {
  const sessions = { assertSession: jest.fn().mockResolvedValue(undefined) };
  const doctors = { findOne: jest.fn() };
  let strategy: JwtStrategy;

  beforeEach(() => {
    strategy = new JwtStrategy(
      { get: () => 'test-only-jwt-secret' } as any,
      {} as any,
      doctors as any,
      sessions as any,
    );
  });

  it('rejects an existing session after a doctor is disabled', async () => {
    doctors.findOne.mockResolvedValue({ id: 1, isActive: false });
    await expect(strategy.validate({ type: 'doctor', sub: 1, sid: 'active' }))
      .rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('allows an active doctor and removes the password', async () => {
    doctors.findOne.mockResolvedValue({ id: 1, isActive: true, password: 'hash' });
    await expect(strategy.validate({ type: 'doctor', sub: 1, sid: 'active' }))
      .resolves.toEqual({ id: 1, isActive: true, type: 'doctor', sid: 'active' });
  });
});
