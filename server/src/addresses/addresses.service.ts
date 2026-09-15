import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Not } from 'typeorm';
import { Address } from './entities/address.entity';
import { CreateAddressDto } from './dto/create-address.dto';
import { UpdateAddressDto } from './dto/update-address.dto';

@Injectable()
export class AddressesService {
  constructor(
    @InjectRepository(Address)
    private readonly addressRepository: Repository<Address>,
  ) {}

  /**
   * 获取用户的所有地址（默认地址排前面）
   */
  async findAll(userId: number): Promise<Address[]> {
    return this.addressRepository.find({
      where: { userId },
      order: { isDefault: 'DESC', createdAt: 'DESC' },
    });
  }

  /**
   * 获取单个地址详情
   */
  async findOne(userId: number, id: number): Promise<Address> {
    const address = await this.addressRepository.findOne({
      where: { id, userId },
    });

    if (!address) {
      throw new NotFoundException('地址不存在');
    }

    return address;
  }

  /**
   * 创建新地址
   */
  async create(
    userId: number,
    createAddressDto: CreateAddressDto,
  ): Promise<Address> {
    // 如果设置为默认地址，先取消其他默认地址
    if (createAddressDto.isDefault) {
      await this.addressRepository.update(
        { userId, isDefault: true },
        { isDefault: false },
      );
    }

    const address = this.addressRepository.create({
      ...createAddressDto,
      userId,
    });

    return this.addressRepository.save(address);
  }

  /**
   * 更新地址
   */
  async update(
    userId: number,
    id: number,
    updateAddressDto: UpdateAddressDto,
  ): Promise<Address> {
    const address = await this.findOne(userId, id);

    // 如果设置为默认地址，先取消其他默认地址
    if (updateAddressDto.isDefault) {
      await this.addressRepository.update(
        { userId, isDefault: true, id: Not(id) },
        { isDefault: false },
      );
    }

    Object.assign(address, updateAddressDto);
    return this.addressRepository.save(address);
  }

  /**
   * 删除地址
   */
  async remove(userId: number, id: number): Promise<void> {
    const address = await this.findOne(userId, id);

    // 如果删除的是默认地址且有其他地址，自动设置第一个为默认
    if (address.isDefault) {
      const otherAddresses = await this.addressRepository.find({
        where: { userId, id: Not(id) },
        take: 1,
      });

      if (otherAddresses.length > 0) {
        await this.addressRepository.update(otherAddresses[0].id, {
          isDefault: true,
        });
      }
    }

    await this.addressRepository.remove(address);
  }

  /**
   * 设置默认地址
   */
  async setDefaultAddress(
    userId: number,
    addressId: number,
  ): Promise<{ success: boolean }> {
    // 验证地址是否属于当前用户
    const address = await this.findOne(userId, addressId);

    // 使用事务确保数据一致性
    await this.addressRepository.manager.transaction(async (manager) => {
      // 取消该用户所有地址的默认状态
      await manager.update(
        Address,
        { userId, isDefault: true },
        { isDefault: false },
      );

      // 设置新默认地址
      await manager.update(Address, { id: addressId }, { isDefault: true });
    });

    return { success: true };
  }
}
