import {
  registerDecorator,
  ValidationOptions,
  ValidationArguments,
} from 'class-validator';

/**
 * 自定义验证器：验证日期必须是过去的日期（不能是未来日期）
 *
 * @example
 * @IsPastDate({ message: '出生日期不能是未来日期' })
 * birthDate: string;
 */
export function IsPastDate(validationOptions?: ValidationOptions) {
  return function (object: object, propertyName: string) {
    registerDecorator({
      name: 'isPastDate',
      target: object.constructor,
      propertyName: propertyName,
      options: validationOptions,
      validator: {
        validate(value: any) {
          // 如果值为空，不进行验证（由 @IsOptional 处理）
          if (!value) {
            return true;
          }

          // 尝试解析日期
          const date = new Date(value);

          // 检查日期是否有效
          if (isNaN(date.getTime())) {
            return false;
          }

          // 检查日期是否是今天或过去
          const today = new Date();
          today.setHours(0, 0, 0, 0); // 清除时间部分，只比较日期

          const compareDate = new Date(date);
          compareDate.setHours(0, 0, 0, 0);

          return compareDate <= today;
        },
        defaultMessage(validationArguments?: ValidationArguments) {
          return `${validationArguments?.property} 不能是未来日期`;
        },
      },
    });
  };
}
