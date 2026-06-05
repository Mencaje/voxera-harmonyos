import { display } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

/** Runtime device class — independent presets for PC / tablet / phone. */
export enum VoxeraFormFactor {
  Phone = 'phone',
  Tablet = 'tablet',
  Pc2in1 = '2in1',
}

export interface DialogSizePx {
  width: number;
  height: number;
}

export interface LegalConsentLayout {
  pagePadding: number;
  titleFontSize: number;
  bodyFontSize: number;
  lineHeight: number;
  buttonHeight: number;
  /** Phone: top padding inside the white panel. */
  pagePaddingTop?: number;
  /** Phone: inner padding above screen bottom (footer controls); panel stays full-screen white. */
  pagePaddingBottom?: number;
  /** Phone: gap between scroll area and footer row. */
  footerBarGapTop?: number;
  /** Phone footer: extra inner padding below footer controls. */
  footerPaddingBottom?: number;
  /** Phone scroll: extra space after last body line so it is not clipped above the footer. */
  scrollBottomPadding?: number;
  /** Phone footer: checkbox label and action button text size. */
  footerFontSize?: number;
  /** Phone: cancel left / confirm bottom-right instead of equal-width row. */
  cornerButtons?: boolean;
  /** Phone: full-screen landscape page instead of subwindow dialog. */
  fullScreen?: boolean;
}

export interface HealthyGamingLayout {
  pagePaddingH: number;
  pagePaddingV: number;
  titleFontSize: number;
  bodyFontSize: number;
  lineHeight: number;
  buttonHeight: number;
  /** Phone: 18+ top-left, confirm bottom-right. */
  cornerButtons?: boolean;
  /** Phone: full-screen landscape page instead of subwindow dialog. */
  fullScreen?: boolean;
}

/** PC / 2in1 — fixed layout; do not reuse on tablet or phone pages. */
export const LEGAL_LAYOUT_PC: LegalConsentLayout = {
  pagePadding: 24,
  titleFontSize: 22,
  bodyFontSize: 14,
  lineHeight: 22,
  buttonHeight: 44,
};

export const LEGAL_LAYOUT_TABLET: LegalConsentLayout = {
  pagePadding: 22,
  titleFontSize: 21,
  bodyFontSize: 15,
  lineHeight: 24,
  buttonHeight: 46,
};

export const LEGAL_LAYOUT_PHONE: LegalConsentLayout = {
  pagePadding: 22,
  pagePaddingTop: 22,
  pagePaddingBottom: 16,
  footerBarGapTop: 10,
  footerPaddingBottom: 0,
  scrollBottomPadding: 16,
  titleFontSize: 20,
  bodyFontSize: 14,
  lineHeight: 22,
  footerFontSize: 12,
  buttonHeight: 34,
  cornerButtons: true,
  fullScreen: true,
};

export const HEALTHY_LAYOUT_PC: HealthyGamingLayout = {
  pagePaddingH: 32,
  pagePaddingV: 32,
  titleFontSize: 22,
  bodyFontSize: 17,
  lineHeight: 30,
  buttonHeight: 46,
};

export const HEALTHY_LAYOUT_TABLET: HealthyGamingLayout = {
  pagePaddingH: 28,
  pagePaddingV: 28,
  titleFontSize: 21,
  bodyFontSize: 16,
  lineHeight: 28,
  buttonHeight: 46,
};

export const HEALTHY_LAYOUT_PHONE: HealthyGamingLayout = {
  pagePaddingH: 28,
  pagePaddingV: 28,
  titleFontSize: 21,
  bodyFontSize: 16,
  lineHeight: 28,
  buttonHeight: 46,
  cornerButtons: true,
  fullScreen: true,
};

export class DeviceFormFactor {
  static current(): VoxeraFormFactor {
    const t = deviceInfo.deviceType;
    if (t === 'tablet') {
      return VoxeraFormFactor.Tablet;
    }
    if (t === '2in1') {
      return VoxeraFormFactor.Pc2in1;
    }
    return VoxeraFormFactor.Phone;
  }

  static isPc2in1(): boolean {
    return DeviceFormFactor.current() === VoxeraFormFactor.Pc2in1;
  }

  static isTablet(): boolean {
    return DeviceFormFactor.current() === VoxeraFormFactor.Tablet;
  }

  static isPhone(): boolean {
    return DeviceFormFactor.current() === VoxeraFormFactor.Phone;
  }

  static legalConsentPage(): string {
    switch (DeviceFormFactor.current()) {
      case VoxeraFormFactor.Tablet:
        return 'pages/LegalConsentTablet';
      case VoxeraFormFactor.Phone:
        return 'pages/LegalConsentPhone';
      default:
        return 'pages/LegalConsent';
    }
  }

  static healthyGamingPage(): string {
    switch (DeviceFormFactor.current()) {
      case VoxeraFormFactor.Tablet:
        return 'pages/HealthyGamingDeclarationTablet';
      case VoxeraFormFactor.Phone:
        return 'pages/HealthyGamingDeclarationPhone';
      default:
        return 'pages/HealthyGamingDeclaration';
    }
  }

  static legalConsentDialogSize(): DialogSizePx {
    const d = DeviceFormFactor.displaySize();
    switch (DeviceFormFactor.current()) {
      case VoxeraFormFactor.Tablet:
        return {
          width: Math.min(1180, Math.floor(d.width * 0.94)),
          height: Math.min(800, Math.floor(d.height * 0.91)),
        };
      case VoxeraFormFactor.Phone:
        /* Match tablet: centered dialog, not edge-to-edge on landscape phones. */
        return {
          width: Math.min(1180, Math.floor(d.width * 0.94)),
          height: Math.min(800, Math.floor(d.height * 0.91)),
        };
      default:
        return { width: 920, height: 680 };
    }
  }

  static healthyGamingDialogSize(): DialogSizePx {
    const d = DeviceFormFactor.displaySize();
    switch (DeviceFormFactor.current()) {
      case VoxeraFormFactor.Tablet:
        return {
          width: Math.min(960, Math.floor(d.width * 0.9)),
          height: Math.min(780, Math.floor(d.height * 0.9)),
        };
      case VoxeraFormFactor.Phone:
        return {
          width: Math.min(960, Math.floor(d.width * 0.9)),
          height: Math.min(780, Math.floor(d.height * 0.9)),
        };
      default:
        return { width: 980, height: 640 };
    }
  }

  private static displaySize(): DialogSizePx {
    try {
      const d = display.getDefaultDisplaySync();
      return { width: d.width, height: d.height };
    } catch {
      return { width: 1280, height: 800 };
    }
  }
}
