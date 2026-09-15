import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  Param,
  UseGuards,
  Query,
  ParseIntPipe,
} from "@nestjs/common";
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiOkResponse,
  ApiResponse,
} from "@nestjs/swagger";
import { CouponService } from "./coupon.service";
import { CreateCouponDto } from "./dto/create-coupon.dto";
import { UpdateCouponDto } from "./dto/update-coupon.dto";
import { QueryCouponDto } from "./dto/query-coupon.dto";
import { ClaimCouponDto } from "./dto/claim-coupon.dto";
import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard";
import { RolesGuard } from "../auth/guards/roles.guard";
import { Roles } from "../auth/decorators/roles.decorator";
import { CurrentUser } from "../common/decorators/current-user.decorator";
import { UserCouponStatus } from "./entities/user-coupon.entity";

@ApiTags("shop/coupons")
@Controller("shop/coupons")
export class CouponController {
  constructor(private readonly couponService: CouponService) {}

  // ========== 用户端 ==========

  /**
   * 获取可领取的优惠券
   */
  @Get("available")
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: "获取可领取的优惠券" })
  getAvailableCoupons(@CurrentUser() user: any) {
    return this.couponService.getAvailableCoupons(user.id);
  }

  /**
   * 领取优惠券
   */
  @Post("claim")
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: "领取优惠券" })
  claimCoupon(@Body() dto: ClaimCouponDto, @CurrentUser() user: any) {
    return this.couponService.claimCoupon(dto, user.id);
  }

  /**
   * 获取我的优惠券
   */
  @Get("my")
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: "获取我的优惠券" })
  getMyCoupons(
    @CurrentUser() user: any,
    @Query("status") status?: UserCouponStatus,
  ) {
    return this.couponService.getMyCoupons(user.id, status);
  }

  /**
   * 获取我的优惠券数量统计
   */
  @Get("my/count")
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: "获取我的优惠券数量统计" })
  getMyCouponCount(@CurrentUser() user: any) {
    return this.couponService.getMyCouponCount(user.id);
  }

  /**
   * 根据扫码领取码获取优惠券详情
   */
  @Get("scan/:claimCode")
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: "根据扫码领取码获取优惠券详情" })
  getCouponDetailByClaimCode(
    @Param("claimCode") claimCode: string,
    @CurrentUser() user: any,
  ) {
    return this.couponService.getCouponDetailByClaimCode(claimCode, user.id);
  }

  // ========== 管理端 ==========

  /**
   * 获取所有优惠券（管理员）
   */
  @Get()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF")
  @ApiBearerAuth()
  @ApiOperation({ summary: "获取所有优惠券" })
  getAllCoupons() {
    return this.couponService.getAllCoupons();
  }

  /**
   * 获取优惠券列表（分页）
   */
  @Get("list")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF")
  @ApiBearerAuth()
  @ApiOperation({ summary: "获取优惠券列表（分页）" })
  getCouponList(@Query() query: QueryCouponDto) {
    return this.couponService.getCouponList(query);
  }

  /**
   * 获取优惠券详情
   */
  @Get(":id")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF")
  @ApiBearerAuth()
  @ApiOperation({ summary: "获取优惠券详情" })
  getCouponDetail(@Param("id", ParseIntPipe) id: number) {
    return this.couponService.findOne(id);
  }

  /**
   * 创建优惠券（管理员）
   */
  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF")
  @ApiBearerAuth()
  @ApiOperation({ summary: "创建优惠券" })
  createCoupon(@Body() createCouponDto: CreateCouponDto) {
    return this.couponService.createCoupon(createCouponDto);
  }

  /**
   * 更新优惠券（管理员）
   */
  @Put(":id")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF")
  @ApiBearerAuth()
  @ApiOperation({ summary: "更新优惠券" })
  updateCoupon(
    @Param("id", ParseIntPipe) id: number,
    @Body() updateCouponDto: UpdateCouponDto,
  ) {
    return this.couponService.updateCoupon(id, updateCouponDto);
  }

  /**
   * 切换优惠券状态（启用/禁用）
   */
  @Put(":id/toggle-status")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF")
  @ApiBearerAuth()
  @ApiOperation({ summary: "切换优惠券状态" })
  toggleCouponStatus(@Param("id", ParseIntPipe) id: number) {
    return this.couponService.toggleCouponStatus(id);
  }

  /**
   * 作废优惠券（管理员）
   */
  @Post(":id/revoke")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF")
  @ApiBearerAuth()
  @ApiOperation({ summary: "作废优惠券" })
  revokeCoupon(@Param("id", ParseIntPipe) id: number) {
    return this.couponService.revokeCoupon(id);
  }

  /**
   * 获取优惠券二维码
   */
  @Get(":id/qrcode")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN", "STAFF")
  @ApiBearerAuth()
  @ApiOperation({ summary: "获取优惠券二维码" })
  @ApiOkResponse({
    description: "二维码生成结果",
    schema: {
      type: "object",
      properties: {
        success: { type: "boolean", description: "是否成功" },
        qrcode: {
          type: "string",
          description: "二维码base64图片（成功时返回）",
        },
        message: { type: "string", description: "错误消息（失败时返回）" },
      },
    },
  })
  getQRCode(@Param("id", ParseIntPipe) id: number) {
    return this.couponService.generateQRCode(id);
  }
}
