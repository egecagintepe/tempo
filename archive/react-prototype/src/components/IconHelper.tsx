import React from 'react';
import {
  Radio,
  Cpu,
  Terminal,
  Globe,
  Languages,
  Film,
  Layout,
  Code2,
  BookOpen,
  GraduationCap,
  Sparkles,
  Zap,
  Flame,
  Clock,
  Compass,
  CheckCircle2,
  Shield,
  Target,
  LucideProps,
} from 'lucide-react';

interface IconHelperProps extends LucideProps {
  name: string;
}

export const CategoryIcon: React.FC<IconHelperProps> = ({ name, ...props }) => {
  switch (name?.toLowerCase()) {
    case 'radio':
      return <Radio {...props} />;
    case 'cpu':
      return <Cpu {...props} />;
    case 'terminal':
      return <Terminal {...props} />;
    case 'globe':
      return <Globe {...props} />;
    case 'languages':
      return <Languages {...props} />;
    case 'film':
      return <Film {...props} />;
    case 'layout':
      return <Layout {...props} />;
    case 'code-2':
    case 'code':
      return <Code2 {...props} />;
    case 'book-open':
    case 'book':
      return <BookOpen {...props} />;
    case 'graduation-cap':
      return <GraduationCap {...props} />;
    case 'shield':
      return <Shield {...props} />;
    case 'target':
      return <Target {...props} />;
    case 'flame':
      return <Flame {...props} />;
    case 'zap':
      return <Zap {...props} />;
    case 'clock':
      return <Clock {...props} />;
    case 'compass':
      return <Compass {...props} />;
    default:
      return <Sparkles {...props} />;
  }
};

export const AVAILABLE_ICONS = [
  'radio',
  'cpu',
  'terminal',
  'globe',
  'languages',
  'film',
  'layout',
  'code-2',
  'book-open',
  'graduation-cap',
  'shield',
  'target',
  'flame',
  'zap',
];
