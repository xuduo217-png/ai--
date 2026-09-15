import {
  Injectable,
  NotFoundException,
  ConflictException,
  Logger,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { SystemConfig } from "./entities/system-config.entity";
import { CreateSystemConfigDto } from "./dto/create-system-config.dto";
import { UpdateSystemConfigDto } from "./dto/update-system-config.dto";
import { QuerySystemConfigDto } from "./dto/query-system-config.dto";
import { PaginatedResult } from "../common/dto/pagination.dto";

/**
 * 系统配置服务
 */
@Injectable()
export class SystemConfigsService {
  private readonly logger = new Logger(SystemConfigsService.name);

  // 默认配置常量
  private readonly DEFAULT_CONTACT_INFO = {
    configKey: "contact_info",
    configValue: {
      wechatQrCode: "",
      hotline: "",
      workingHours: "",
    },
    description: "联系方式配置",
  };

  private readonly DEFAULT_PLATFORM_FEE = {
    configKey: "platform_fee_rate",
    configValue: {
      feeRate: 5,
    },
    description: "平台手续费率配置（百分比）",
  };

  private readonly DEFAULT_EMERGENCY_CENTER = {
    configKey: "emergency_center",
    configValue: {
      emergencyTime: "24小时在线",
      emergencyHotline: "400-000-0000",
    },
    description: "急救中心配置",
  };

  private readonly DEFAULT_MALL_HOME_HOT_PRODUCTS = {
    configKey: "mall_home_hot_products",
    configValue: {
      productIds: [],
    },
    description: "商城首页热门商品配置",
  };

  private readonly DEFAULT_MALL_HOME_BANNERS = {
    configKey: "mall_home_banners",
    configValue: {
      banners: [],
    },
    description: "商城首页 Banner 配置",
  };

  private readonly DEFAULT_HOME_MENU_ICONS = {
    configKey: "home_menu_icons",
    configValue: {
      icons: {},
    },
    description: "App 首页菜单图标配置",
  };

  private readonly DEFAULT_HOME_AI_DIAGNOSIS_BANNER = {
    configKey: "home_ai_diagnosis_banner",
    configValue: {
      imageUrl: "",
    },
    description: "App 首页AI智能诊断Banner配置",
  };

  private readonly DEFAULT_MALL_HOME_POPUP_IMAGE = {
    configKey: "mall_home_popup_image",
    configValue: {
      imageUrl: "",
    },
    description: "商城首页弹窗配置",
  };

  private readonly DEFAULT_SCROLLING_ANNOUNCEMENT = {
    configKey: "scrolling_announcement",
    configValue: {
      source: "fixed",
      announcementText: "",
    },
    description: "App 首页滚动公告配置",
  };

  private readonly DEFAULT_AI_DIAGNOSIS_CONFIG = {
    configKey: "ai_diagnosis_config",
    configValue: {
      bodyTemperatureOptions: [
        "偏低（低于37.5℃）",
        "正常（37.5℃ - 39.2℃）",
        "偏高（39.3℃ - 40℃）",
        "高热（高于40℃）",
      ],
      heartRateOptions: ["偏慢", "正常", "偏快", "明显过快"],
      breatheOptions: ["偏慢", "正常", "偏快", "呼吸困难"],
      disclaimerTitle: "风险提示",
      disclaimerContent:
        "AI问诊结果仅供参考，不能替代线下执业兽医的面诊、检查与治疗建议。如宠物出现精神沉郁、持续呕吐腹泻、呼吸困难、抽搐、高热等紧急症状，请立即前往线下宠物医院就诊。",
      disclaimerConfirmText: "我已知晓，继续问诊",
      disclaimerCancelText: "再想想",
    },
    description: "AI问诊基础配置",
  };

  private readonly DEFAULT_MEDICAL_CONSULTATION_CONFIG = {
    configKey: "medical_consultation_config",
    configValue: {
      paymentPromptDisclaimer:
        "在线咨询仅供宠物健康管理参考，不能替代线下诊疗。若宠物出现急症或症状加重，请及时前往正规宠物医院就诊。",
    },
    description: "医疗咨询基础配置",
  };

  constructor(
    @InjectRepository(SystemConfig)
    private readonly systemConfigRepository: Repository<SystemConfig>,
  ) {}

  /**
   * 创建新配置
   */
  async create(
    createSystemConfigDto: CreateSystemConfigDto,
  ): Promise<SystemConfig> {
    // 检查 configKey 是否已存在
    const existing = await this.systemConfigRepository.findOne({
      where: { configKey: createSystemConfigDto.configKey },
    });

    if (existing) {
      throw new ConflictException(
        `配置标识 ${createSystemConfigDto.configKey} 已存在`,
      );
    }

    const config = this.systemConfigRepository.create(createSystemConfigDto);
    return await this.systemConfigRepository.save(config);
  }

  /**
   * 获取所有配置（分页，仅管理员）
   */
  async findAll(
    queryDto: QuerySystemConfigDto,
  ): Promise<PaginatedResult<SystemConfig>> {
    const { page = 1, pageSize = 10, configKey } = queryDto;
    const queryBuilder =
      this.systemConfigRepository.createQueryBuilder("config");

    // 按 configKey 筛选
    if (configKey) {
      queryBuilder.andWhere("config.configKey LIKE :configKey", {
        configKey: `%${configKey}%`,
      });
    }

    // 排序
    queryBuilder.orderBy("config.createdAt", "DESC");

    // 分页
    queryBuilder.skip((page - 1) * pageSize).take(pageSize);

    const [list, total] = await queryBuilder.getManyAndCount();

    return {
      data: list,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  /**
   * 根据 configKey 获取配置（公开接口）
   */
  async findByKey(configKey: string): Promise<SystemConfig> {
    const config = await this.systemConfigRepository.findOne({
      where: { configKey },
    });

    if (!config) {
      throw new NotFoundException(`配置 ${configKey} 不存在`);
    }

    return config;
  }

  /**
   * 更新配置
   */
  async update(
    configKey: string,
    updateSystemConfigDto: UpdateSystemConfigDto,
  ): Promise<SystemConfig> {
    const config = await this.findByKey(configKey);

    // 更新字段
    Object.assign(config, updateSystemConfigDto);

    return await this.systemConfigRepository.save(config);
  }

  /**
   * 删除配置
   */
  async remove(configKey: string): Promise<void> {
    const config = await this.findByKey(configKey);
    await this.systemConfigRepository.remove(config);
  }

  /**
   * 初始化默认配置
   * 在模块启动时调用，确保必需的配置项存在
   */
  async initDefaultConfigs(): Promise<void> {
    try {
      const defaultConfigs = [
        this.DEFAULT_CONTACT_INFO,
        this.DEFAULT_PLATFORM_FEE,
        this.DEFAULT_EMERGENCY_CENTER,
        this.DEFAULT_MALL_HOME_HOT_PRODUCTS,
        this.DEFAULT_MALL_HOME_BANNERS,
        this.DEFAULT_HOME_MENU_ICONS,
        this.DEFAULT_HOME_AI_DIAGNOSIS_BANNER,
        this.DEFAULT_MALL_HOME_POPUP_IMAGE,
        this.DEFAULT_SCROLLING_ANNOUNCEMENT,
        this.DEFAULT_AI_DIAGNOSIS_CONFIG,
        this.DEFAULT_MEDICAL_CONSULTATION_CONFIG,
      ];

      for (const defaultConfig of defaultConfigs) {
        const existingConfig = await this.systemConfigRepository.findOne({
          where: { configKey: defaultConfig.configKey },
        });

        if (existingConfig) {
          this.logger.log(
            `系统配置已存在，跳过初始化 (key: ${defaultConfig.configKey})`,
          );
          continue;
        }

        const newConfig = this.systemConfigRepository.create(defaultConfig);
        await this.systemConfigRepository.save(newConfig);

        this.logger.log(
          `✅ 系统配置初始化成功 (key: ${defaultConfig.configKey})`,
        );
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : "未知错误";
      const stack = error instanceof Error ? error.stack : undefined;

      this.logger.error(`❌ 系统配置初始化失败: ${message}`, stack);
      throw error;
    }
  }
}
